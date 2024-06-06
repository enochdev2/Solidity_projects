// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {NFTCollateral} from "./NFTCollateral.sol";
import {VaultAccounting} from "./libraries/VaultAccounting.sol";
import {PoolStructs} from "./interfaces/PoolStructs.sol";
import {IFlashLoanReceiver} from "./interfaces/IFlashLoanReceiver.sol";
import {IFlashAirdropReceiver} from "./interfaces/IFlashAirdropReceiver.sol";
import {InterestRate} from "./libraries/InterestRate.sol";
import {Pausable} from "./utils/Pausable.sol";
import "./libraries/TokenHelper.sol";

contract LendingPool is Pausable, NFTCollateral {
    using VaultAccounting for PoolStructs.Vault;
    using InterestRate for PoolStructs.VaultInfo;
    using TokenHelper for address;

      mapping(address => PoolStructs.TokenVault) private vaults;
    // user => token => (colletral, borrow) shares
    mapping(address => mapping(address => PoolStructs.AccountShares))
        private userShares;
    // user => NFT address => tokenId => (liquidator, liquidationTime)
    mapping(address => mapping(address => mapping(uint256 => PoolStructs.LiquidateWarn)))
        private nftLiquidationWarning;

          error TooHighSlippage(uint256 sharesOutOrAmountIn);
    error InsufficientBalance();
    error BelowHeathFactor();
    error BorrowerIsSolvant();
    error SelfLiquidation();
    error InvalidNFTLiquidation(
        address borrower,
        address nftAddress,
        uint256 tokenId
    );
    error InvalidFeeRate(uint256 fee);
    error InvalidReserveRatio(uint256 ratio);
    error FlashloanPaused(address token);
    error FlashloanFailed();
    error FlashAirdropFailed();
    error NoLiquidateWarn();
    error WarningDelayHasNotPassed();
    error MustRepayMoreDebt();
    error LiquidatorDelayHasNotPassed();
    error EmptyArray();
    error ArrayMismatch();


    event Deposit(address user, address token, uint256 amount, uint256 shares);
    event Borrow(address user, address token, uint256 amount, uint256 shares);
    event Repay(address user, address token, uint256 amount, uint256 shares);
    event Withdraw(address user, address token, uint256 amount, uint256 shares);
    event Liquidated(
        address borrower,
        address liquidator,
        uint256 repaidAmount,
        uint256 liquidatedCollateral,
        uint256 reward
    );
    event UpdateInterestRate(uint256 elapsedTime, uint64 newInterestRate);
    event AccruedInterest(
        uint64 interestRatePerSec,
        uint256 interestEarned,
        uint256 feesAmount,
        uint256 feesShare
    );
    event FlashloanSuccess(
        address initiator,
        address[] tokens,
        uint256[] amounts,
        uint256[] fees,
        bytes data
    );
    event FlashAirdropSuccess(
        address initiator,
        address nft,
        uint256[] tokenIds,
        bytes data
    );



     event DepositNFT(address user, address nftAddress, uint256 tokenId);
    event WithdrawNFT(
        address user,
        address recipient,
        address nftAddress,
        uint256 tokenId
    );
    event LiquidingNFTWarning(
        address liquidator,
        address borrower,
        address nftAddress,
        uint256 tokenId
    );
    event LiquidateNFTStopped(
        address borrower,
        address nftAddress,
        uint256 tokenId
    );

    event NFTLiquidated(
        address liquidator,
        address borrower,
        address nftAddress,
        uint256 tokenId,
        uint256 totalRepayDebt,
        uint256 nftBuyPrice
    );
    event NewVaultSetup(address token, PoolStructs.VaultSetupParams params);

      constructor(
        address daiAddress,
        address daiPriceFeed,
        PoolStructs.VaultSetupParams memory daiVaultParams
    ) {
        _setupVault(
            daiAddress,
            daiPriceFeed,
            PoolStructs.TokenType.ERC20,
            daiVaultParams,
            true
        );
    }


     /*//////////////////////////////////////////////////////////////
                        ERC20 Logic functions
    //////////////////////////////////////////////////////////////*/


    function transferERC20(
            address _token,
            address _from,
            address _to,
            uint256 _amount
            ) internal {
            bool success;
            if (_from == address(this)) {
                success = IERC20(_token).transfer(_to, _amount);
            } else {
                success = IERC20(_token).transferFrom(_from, _to, _amount);
            }
            if (!success) revert TransferFailed();
    }


    function WhenNotPaused(address vault) internal view {
            if (pausedStatus(vault)) revert isPaused();
    }

    function allowedToken(address token) internal view {
            if (!supportedTokens[token].supported) revert TokenNotSupported();
        }


    function _accrueInterest(
        address token
        )
        internal
        returns (
            uint256 _interestEarned,
            uint256 _feesAmount,
            uint256 _feesShare,
            uint64 newRate
        )
    {
        PoolStructs.TokenVault memory _vault = vaults[token];
        if (_vault.totalAsset.amount == 0) {
            return (0, 0, 0, 0);
        }

        // Add interest only once per block
        PoolStructs.VaultInfo memory _currentRateInfo = _vault.vaultInfo;
        if (_currentRateInfo.lastTimestamp == block.timestamp) {
            newRate = _currentRateInfo.ratePerSec;
            return (_interestEarned, _feesAmount, _feesShare, newRate);
        }
    }


    function supply(
        address token,
        uint256 amount,
        uint256 minSharesOut
    ) external {
        WhenNotPaused(token);
        allowedToken(token);
        _accrueInterest(token);

        token.transferERC20(msg.sender, address(this), amount);
        uint256 shares = vaults[token].totalAsset.toShares(amount, false);
        if (shares < minSharesOut) revert TooHighSlippage(shares);

        vaults[token].totalAsset.shares += uint128(shares);
        vaults[token].totalAsset.amount += uint128(amount);
        userShares[msg.sender][token].collateral += shares;

        emit Deposit(msg.sender, token, amount, shares);
    }





    function vaultAboveReserveRatio(
        address token,
        uint256 pulledAmount
        ) internal view returns (bool isAboveReserveRatio) {
        uint256 minVaultReserve = (vaults[token].totalAsset.amount *
            vaults[token].vaultInfo.reserveRatio) / BPS;
        isAboveReserveRatio =
            vaults[token].totalAsset.amount != 0 &&
            IERC20(token).balanceOf(address(this)) >=
            minVaultReserve + pulledAmount;
    }

    function healthFactor(address user) public view returns (uint256 factor) {
        (
            uint256 totalTokenCollateral,
            uint256 totalNFTCollateral,
            uint256 totalBorrowValue
        ) = getUserData(user);

        uint256 userTotalCollateralValue = totalTokenCollateral +
            totalNFTCollateral;
        if (totalBorrowValue == 0) return 100 * MIN_HEALTH_FACTOR;
        uint256 collateralValueWithThreshold = (userTotalCollateralValue *
            LIQUIDATION_THRESHOLD) / BPS;
        factor =
            (collateralValueWithThreshold * MIN_HEALTH_FACTOR) /
            totalBorrowValue;
    }

    function vaultAboveReserveRatio(
        address token,
        uint256 pulledAmount
         ) internal view returns (bool isAboveReserveRatio) {
        uint256 minVaultReserve = (vaults[token].totalAsset.amount *
            vaults[token].vaultInfo.reserveRatio) / BPS;
        isAboveReserveRatio =
            vaults[token].totalAsset.amount != 0 &&
            IERC20(token).balanceOf(address(this)) >=
            minVaultReserve + pulledAmount;
    }

    function transferERC20(
        address _token,
        address _from,
        address _to,
        uint256 _amount
        ) internal {
        bool success;
        if (_from == address(this)) {
            success = IERC20(_token).transfer(_to, _amount);
        } else {
            success = IERC20(_token).transferFrom(_from, _to, _amount);
        }
        if (!success) revert TransferFailed();
    }

    function _accrueInterest(
        address token
        )
        internal
        returns (
            uint256 _interestEarned,
            uint256 _feesAmount,
            uint256 _feesShare,
            uint64 newRate
        )
    {
        PoolStructs.TokenVault memory _vault = vaults[token];
        if (_vault.totalAsset.amount == 0) {
            return (0, 0, 0, 0);
        }

        // Add interest only once per block
        PoolStructs.VaultInfo memory _currentRateInfo = _vault.vaultInfo;
        if (_currentRateInfo.lastTimestamp == block.timestamp) {
            newRate = _currentRateInfo.ratePerSec;
            return (_interestEarned, _feesAmount, _feesShare, newRate);
        }
    }

 function allowedToken(address token) internal view {
        if (!supportedTokens[token].supported) revert TokenNotSupported();
    }




      function borrow(address token, uint256 amount) external {
        WhenNotPaused(token);
        if (!vaultAboveReserveRatio(token, amount))
            revert InsufficientBalance();
        _accrueInterest(token);

        uint256 shares = vaults[token].totalBorrow.toShares(amount, false);
        vaults[token].totalBorrow.shares += uint128(shares);
        vaults[token].totalBorrow.amount += uint128(amount);
        userShares[msg.sender][token].borrow += shares;

        token.transferERC20(address(this), msg.sender, amount);
        if (healthFactor(msg.sender) < MIN_HEALTH_FACTOR)
            revert BelowHeathFactor();

        emit Borrow(msg.sender, token, amount, shares);
    }





 function transferERC20(
            address _token,
            address _from,
            address _to,
            uint256 _amount
            ) internal {
            bool success;
            if (_from == address(this)) {
                success = IERC20(_token).transfer(_to, _amount);
            } else {
                success = IERC20(_token).transferFrom(_from, _to, _amount);
            }
            if (!success) revert TransferFailed();
    }

    function _accrueInterest(
        address token
        )
        internal
        returns (
            uint256 _interestEarned,
            uint256 _feesAmount,
            uint256 _feesShare,
            uint64 newRate
        )
    {
        PoolStructs.TokenVault memory _vault = vaults[token];
        if (_vault.totalAsset.amount == 0) {
            return (0, 0, 0, 0);
        }

        // Add interest only once per block
        PoolStructs.VaultInfo memory _currentRateInfo = _vault.vaultInfo;
        if (_currentRateInfo.lastTimestamp == block.timestamp) {
            newRate = _currentRateInfo.ratePerSec;
            return (_interestEarned, _feesAmount, _feesShare, newRate);
        }
    }




     function repay(address token, uint256 amount) external {
        _accrueInterest(token);
        uint256 userBorrowShare = userShares[msg.sender][token].borrow;
        uint256 shares = vaults[token].totalBorrow.toShares(amount, true);
        if (amount == type(uint256).max || shares > userBorrowShare) {
            shares = userBorrowShare;
            amount = vaults[token].totalBorrow.toAmount(shares, true);
        }
        token.transferERC20(msg.sender, address(this), amount);
        unchecked {
            vaults[token].totalBorrow.shares -= uint128(shares);
            vaults[token].totalBorrow.amount -= uint128(amount);
            userShares[msg.sender][token].borrow = userBorrowShare - shares;
        }
        emit Repay(msg.sender, token, amount, shares);
    }



function _withdraw(
        address token,
        uint256 amount,
        uint256 minAmountOutOrMaxShareIn,
        bool share
    ) internal {
        _accrueInterest(token);

        uint256 userCollShares = userShares[msg.sender][token].collateral;
        uint256 shares;
        if (share) {
            // redeem shares
            shares = amount;
            amount = vaults[token].totalAsset.toAmount(shares, false);
            if (amount < minAmountOutOrMaxShareIn)
                revert TooHighSlippage(amount);
        } else {
            // withdraw amount
            shares = vaults[token].totalAsset.toShares(amount, false);
            if (shares > minAmountOutOrMaxShareIn)
                revert TooHighSlippage(shares);
        }
        if (
            userCollShares < shares ||
            IERC20(token).balanceOf(address(this)) < amount
        ) revert InsufficientBalance();
        unchecked {
            vaults[token].totalAsset.shares -= uint128(shares);
            vaults[token].totalAsset.amount -= uint128(amount);
            userShares[msg.sender][token].collateral -= shares;
}




     function withdraw(
        address token,
        uint256 amount,
        uint256 maxSharesIn
    ) external {
        _withdraw(token, amount, maxSharesIn, false);
    }


     function redeem(
        address token,
        uint256 shares,
        uint256 minAmountOut
    ) external {
        _withdraw(token, shares, minAmountOut, true);
    }




     function healthFactor(address user) public view returns (uint256 factor) {
        (
            uint256 totalTokenCollateral,
            uint256 totalNFTCollateral,
            uint256 totalBorrowValue
        ) = getUserData(user);

        uint256 userTotalCollateralValue = totalTokenCollateral +
            totalNFTCollateral;
        if (totalBorrowValue == 0) return 100 * MIN_HEALTH_FACTOR;
        uint256 collateralValueWithThreshold = (userTotalCollateralValue *
            LIQUIDATION_THRESHOLD) / BPS;
        factor =
            (collateralValueWithThreshold * MIN_HEALTH_FACTOR) /
            totalBorrowValue;
    }






    function liquidate(
        address account,
        address collateral,
        address userBorrowToken,
        uint256 amountToLiquidate
    ) external {
        if (msg.sender == account) revert SelfLiquidation();
        uint256 accountHF = healthFactor(account);
        if (accountHF >= MIN_HEALTH_FACTOR) revert BorrowerIsSolvant();

        uint256 collateralShares = userShares[account][collateral].collateral;
        uint256 borrowShares = userShares[account][userBorrowToken].borrow;
        if (collateralShares == 0 || borrowShares == 0) return;
        {
            uint256 totalBorrowAmount = vaults[userBorrowToken]
                .totalBorrow
                .toAmount(borrowShares, true);

            // if HF is above CLOSE_FACTOR_HF_THRESHOLD allow only partial liquidation
            // else full liquidation is possible
            uint256 maxBorrowAmountToLiquidate = accountHF >=
                CLOSE_FACTOR_HF_THRESHOLD
                ? (totalBorrowAmount * DEFAULT_LIQUIDATION_CLOSE_FACTOR) / BPS
                : totalBorrowAmount;
            amountToLiquidate = amountToLiquidate > maxBorrowAmountToLiquidate
                ? maxBorrowAmountToLiquidate
                : amountToLiquidate;
        }

        uint256 collateralAmountToLiquidate;
        uint256 liquidationReward;
        {
            // avoid stack too deep error
            address user = account;
            address borrowToken = userBorrowToken;
            address collToken = collateral;
            uint256 liquidationAmount = amountToLiquidate;

            uint256 _userTotalCollateralAmount = vaults[collToken]
                .totalAsset
                .toAmount(collateralShares, false);

            uint256 collateralPrice = getTokenPrice(collToken);
            uint256 borrowTokenPrice = getTokenPrice(borrowToken);
            uint8 collateralDecimals = collToken.tokenDecimals();
            uint8 borrowTokenDecimals = borrowToken.tokenDecimals();

            collateralAmountToLiquidate =
                (liquidationAmount *
                    borrowTokenPrice *
                    10 ** collateralDecimals) /
                (collateralPrice * 10 ** borrowTokenDecimals);
            uint256 maxLiquidationReward = (collateralAmountToLiquidate *
                LIQUIDATION_REWARD) / BPS;
            if (collateralAmountToLiquidate > _userTotalCollateralAmount) {
                collateralAmountToLiquidate = _userTotalCollateralAmount;
                liquidationAmount =
                    ((_userTotalCollateralAmount *
                        collateralPrice *
                        10 ** borrowTokenDecimals) / borrowTokenPrice) *
                    10 ** collateralDecimals;
                amountToLiquidate = liquidationAmount;
            } else {
                uint256 collateralBalanceAfter = _userTotalCollateralAmount -
                    collateralAmountToLiquidate;
                liquidationReward = maxLiquidationReward >
                    collateralBalanceAfter
                    ? collateralBalanceAfter
                    : maxLiquidationReward;
            }

            // Update borrow vault
            uint128 repaidBorrowShares = uint128(
                vaults[borrowToken].totalBorrow.toShares(
                    liquidationAmount,
                    false
                )
            );
            vaults[borrowToken].totalBorrow.shares -= repaidBorrowShares;
            vaults[borrowToken].totalBorrow.amount -= uint128(
                liquidationAmount
            );

            // Update collateral vault
            uint128 liquidatedCollShares = uint128(
                vaults[collToken].totalAsset.toShares(
                    collateralAmountToLiquidate + liquidationReward,
                    false
                )
            );
            vaults[collToken].totalAsset.shares -= liquidatedCollShares;
            vaults[collToken].totalAsset.amount -= uint128(
                collateralAmountToLiquidate + liquidationReward
            );
            // Update borrower collateral and borrow shares
            userShares[user][borrowToken].borrow -= repaidBorrowShares;
            userShares[user][collToken].collateral -= liquidatedCollShares;
        }

        // Repay borrowed amount
        userBorrowToken.transferERC20(
            msg.sender,
            address(this),
            amountToLiquidate
        );
        // Transfer collateral & liquidation reward to liquidator
        collateral.transferERC20(
            address(this),
            msg.sender,
            collateralAmountToLiquidate + liquidationReward
        );

        emit Liquidated(
            account,
            msg.sender,
            amountToLiquidate,
            collateralAmountToLiquidate + liquidationReward,
            liquidationReward
        );
    }


     function flashloan(
        address receiverAddress,
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes calldata data
    ) external {
        if (tokens.length == 0) revert EmptyArray();
        if (tokens.length != amounts.length) revert ArrayMismatch();

        IFlashLoanReceiver receiver = IFlashLoanReceiver(receiverAddress);
        uint256[] memory fees = new uint256[](tokens.length);
        for (uint256 i; i < tokens.length; ) {
            if (maxFlashLoan(tokens[i]) == 0) revert FlashloanPaused(tokens[i]);
            fees[i] = flashFee(tokens[i], amounts[i]);
            tokens[i].transferERC20(address(this), receiverAddress, amounts[i]);
            unchecked {
                ++i;
            }
        }
        if (!receiver.onFlashLoan(msg.sender, tokens, amounts, fees, data))
            revert FlashloanFailed();

        uint256 amountPlusFee;
        for (uint256 i; i < tokens.length; ) {
            amountPlusFee = amounts[i] + fees[i];
            tokens[i].transferERC20(
                receiverAddress,
                address(this),
                amountPlusFee
            );
            vaults[tokens[i]].totalAsset.amount += uint128(fees[i]);
            unchecked {
                ++i;
            }
        }

        emit FlashloanSuccess(msg.sender, tokens, amounts, fees, data);
    } 



     function _accrueInterest(
        address token
        )
        internal
        returns (
            uint256 _interestEarned,
            uint256 _feesAmount,
            uint256 _feesShare,
            uint64 newRate
        )
    {
        PoolStructs.TokenVault memory _vault = vaults[token];
        if (_vault.totalAsset.amount == 0) {
            return (0, 0, 0, 0);
        }

        // Add interest only once per block
        PoolStructs.VaultInfo memory _currentRateInfo = _vault.vaultInfo;
        if (_currentRateInfo.lastTimestamp == block.timestamp) {
            newRate = _currentRateInfo.ratePerSec;
            return (_interestEarned, _feesAmount, _feesShare, newRate);
        }
    }


      function accrueInterest(
        address token
    )
        external
        returns (
            uint256 _interestEarned,
            uint256 _feesAmount,
            uint256 _feesShare,
            uint64 _newRate
        )
    {
        return _accrueInterest(token);
    }








 function tokenDecimals(
        address token
    ) internal view returns (uint8 decimals) {
        decimals = IERC20Metadata(token).decimals();
    }

   function getTokenPrice(address token) public view returns (uint256 price) {
        if (!supportedTokens[token].supported) return 0;
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            supportedTokens[token].usdPriceFeed
        );
        price = priceFeed.getPrice();
    }

  function flashFee(
        address token,
        uint256 amount
    ) public view returns (uint256) {
        return (amount * vaults[token].vaultInfo.flashFeeRate) / BPS;
    }

 function toShares(
        PoolStructs.Vault memory total,
        uint256 amount,
        bool roundUp
    ) internal pure returns (uint256 shares) {
        if (total.amount == 0) {
            shares = amount;
        } else {
            shares = (amount * total.shares) / total.amount;
            if (roundUp && (shares * total.amount) / total.shares < amount) {
                shares = shares + 1;
            }
        }
    }

function toAmount(
        PoolStructs.Vault memory total,
        uint256 shares,
        bool roundUp
    ) internal pure returns (uint256 amount) {
        if (total.shares == 0) {
            amount = shares;
        } else {
            amount = (shares * total.amount) / total.shares;
            if (roundUp && (amount * total.shares) / total.amount < shares) {
                amount = amount + 1;
            }
        }
    }

function _withdraw(
        address token,
        uint256 amount,
        uint256 minAmountOutOrMaxShareIn,
        bool share
    ) internal {
        _accrueInterest(token);

        uint256 userCollShares = userShares[msg.sender][token].collateral;
        uint256 shares;
        if (share) {
            // redeem shares
            shares = amount;
            amount = vaults[token].totalAsset.toAmount(shares, false);
            if (amount < minAmountOutOrMaxShareIn)
                revert TooHighSlippage(amount);
        } else {
            // withdraw amount
            shares = vaults[token].totalAsset.toShares(amount, false);
            if (shares > minAmountOutOrMaxShareIn)
                revert TooHighSlippage(shares);
        }
        if (
            userCollShares < shares ||
            IERC20(token).balanceOf(address(this)) < amount
        ) revert InsufficientBalance();
        unchecked {
            vaults[token].totalAsset.shares -= uint128(shares);
            vaults[token].totalAsset.amount -= uint128(amount);
            userShares[msg.sender][token].collateral -= shares;
}

        token.transferERC20(address(this), msg.sender, amount);
        if (healthFactor(msg.sender) < MIN_HEALTH_FACTOR)
            revert BelowHeathFactor();
        emit Withdraw(msg.sender, token, amount, shares);
    }

   function healthFactor(address user) public view returns (uint256 factor) {
        (
            uint256 totalTokenCollateral,
            uint256 totalNFTCollateral,
            uint256 totalBorrowValue
        ) = getUserData(user);

        uint256 userTotalCollateralValue = totalTokenCollateral +
            totalNFTCollateral;
        if (totalBorrowValue == 0) return 100 * MIN_HEALTH_FACTOR;
        uint256 collateralValueWithThreshold = (userTotalCollateralValue *
            LIQUIDATION_THRESHOLD) / BPS;
        factor =
            (collateralValueWithThreshold * MIN_HEALTH_FACTOR) /
            totalBorrowValue;
    }

    function vaultAboveReserveRatio(
        address token,
        uint256 pulledAmount
    ) internal view returns (bool isAboveReserveRatio) {
        uint256 minVaultReserve = (vaults[token].totalAsset.amount *
            vaults[token].vaultInfo.reserveRatio) / BPS;
        isAboveReserveRatio =
            vaults[token].totalAsset.amount != 0 &&
            IERC20(token).balanceOf(address(this)) >=
            minVaultReserve + pulledAmount;
    }

    function transferERC20(
        address _token,
        address _from,
        address _to,
        uint256 _amount
        ) internal {
        bool success;
        if (_from == address(this)) {
            success = IERC20(_token).transfer(_to, _amount);
        } else {
            success = IERC20(_token).transferFrom(_from, _to, _amount);
        }
        if (!success) revert TransferFailed();
    }

    function _accrueInterest(
        address token
        )
        internal
        returns (
            uint256 _interestEarned,
            uint256 _feesAmount,
            uint256 _feesShare,
            uint64 newRate
        )
    {
        PoolStructs.TokenVault memory _vault = vaults[token];
        if (_vault.totalAsset.amount == 0) {
            return (0, 0, 0, 0);
        }

        // Add interest only once per block
        PoolStructs.VaultInfo memory _currentRateInfo = _vault.vaultInfo;
        if (_currentRateInfo.lastTimestamp == block.timestamp) {
            newRate = _currentRateInfo.ratePerSec;
            return (_interestEarned, _feesAmount, _feesShare, newRate);
        }
    }
 function allowedToken(address token) internal view {
        if (!supportedTokens[token].supported) revert TokenNotSupported();
    }

function WhenNotPaused(address vault) internal view {
        if (pausedStatus(vault)) revert isPaused();
    }

}    