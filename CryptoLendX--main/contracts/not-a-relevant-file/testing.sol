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

 /*//////////////////////////////////////////////////////////////
                        NFT Logic functions
    //////////////////////////////////////////////////////////////*/

     function depositNFT(address nftAddress, uint256 tokenId) external {
        WhenNotPaused(address(0)); // pool is not paused
        _depositNFT(nftAddress, tokenId);
        emit DepositNFT(msg.sender, nftAddress, tokenId);
    }

     function withdrawNFT(
        address recipient,
        address nftAddress,
        uint256 tokenId
    ) external {
        _withdrawNFT(msg.sender, recipient, nftAddress, tokenId);
        if (healthFactor(msg.sender) < MIN_HEALTH_FACTOR)
            revert BelowHeathFactor();
        emit WithdrawNFT(msg.sender, recipient, nftAddress, tokenId);
    }

     function triggerNFTLiquidation(
        address account,
        address nftAddress,
        uint256 tokenId
    ) external {
        if (!hasDepositedNFT(account, nftAddress, tokenId)) revert InvalidNFT();
        uint256 totalTokenCollateralValue = getUserTotalTokenCollateral(
            account
        );
        // NFT is liquidatable if HF < MIN_HEALTH_FACTOR && totalTokenCollateralValue == 0
        if (
            healthFactor(account) >= MIN_HEALTH_FACTOR ||
            totalTokenCollateralValue != 0
        ) revert InvalidNFTLiquidation(account, nftAddress, tokenId);

        PoolStructs.LiquidateWarn storage warning = nftLiquidationWarning[
            account
        ][nftAddress][tokenId];
        warning.liquidator = msg.sender;
        warning.liquidationTimestamp = uint64(
            block.timestamp + NFT_WARNING_DELAY
        );

        emit LiquidingNFTWarning(msg.sender, account, nftAddress, tokenId);
    }

     function stopNFTLiquidation(
        address account,
        address nftAddress,
        uint256 tokenId
    ) external {
        if (healthFactor(account) < MIN_HEALTH_FACTOR)
            revert BelowHeathFactor();
        delete nftLiquidationWarning[account][nftAddress][tokenId];
        emit LiquidateNFTStopped(account, nftAddress, tokenId);
    }


     function executeNFTLiquidation(
        address account,
        address nftAddress,
        uint256 tokenId,
        address[] calldata repayTokens,
        uint256[] calldata repayAmounts
    ) external {
        if (repayTokens.length == 0) revert EmptyArray();
        if (repayTokens.length != repayAmounts.length) revert ArrayMismatch();
        canLiquidateNFT(account, nftAddress, tokenId);

        uint256 totalDebtValue = getUserTotalBorrow(account);
        uint256 nftFloorPrice = getTokenPrice(nftAddress);
        uint256 totalRepaidDebtValue;
        {
            // avoid stack too deep
            address borrower = account;
            address token;
            uint256 amount;
            uint256 borrowShares;
            for (uint256 i; i < repayTokens.length; ) {
                token = repayTokens[i];
                amount = repayAmounts[i];
                _accrueInterest(token);
                borrowShares = vaults[token].totalBorrow.toShares(amount, true);
                // repay borrower debt from liquidator
                token.transferERC20(msg.sender, address(this), amount);
                // update borrow vault
                vaults[token].totalBorrow.shares -= uint128(borrowShares);
                vaults[token].totalBorrow.amount -= uint128(amount);

                // update borrower shares
                userShares[borrower][token].borrow -= uint128(borrowShares);

                // increase total debt repaid value
                totalRepaidDebtValue += getAmountInUSD(token, amount);
                unchecked {
                    ++i;
                }
            }

            // must repay at least debt equivalent of half NFT value
            if (
                totalDebtValue > nftFloorPrice &&
                totalRepaidDebtValue <
                (nftFloorPrice * DEFAULT_LIQUIDATION_CLOSE_FACTOR) / BPS
            ) revert MustRepayMoreDebt();
        }

        uint256 nftBuyPrice;
        {
            // avoid stack too deep
            address borrower = account;
            // liquidator will pay less to buy NFT
            // must deduct repaidDebtValue and liquidator bonus from NFT price
            uint256 totalLiquidatorDiscount = (totalRepaidDebtValue *
                (BPS + NFT_LIQUIDATION_DISCOUNT)) / BPS;
            nftBuyPrice = nftFloorPrice - totalLiquidatorDiscount;

            address DAI = supportedERC20s[0];
            // but NFT with discounted price, DAI is used for payment
            DAI.transferERC20(msg.sender, address(this), nftBuyPrice);

            // supply remaining DAI onbehalf of borrower
            uint256 shares = vaults[DAI].totalAsset.toShares(
                nftBuyPrice,
                false
            );
            vaults[DAI].totalAsset.shares += uint128(shares);
            vaults[DAI].totalAsset.amount += uint128(nftBuyPrice);
            userShares[borrower][DAI].collateral += shares;
        }

        // transfer NFT to liquidator
        _withdrawNFT(account, msg.sender, nftAddress, tokenId);

        emit NFTLiquidated(
            msg.sender,
            account,
            nftAddress,
            tokenId,
            totalRepaidDebtValue,
            nftBuyPrice
        );
    }

     function flashAirdrop(
        address receiverAddress,
        address nftAddress,
        uint256[] calldata tokenIds,
        bytes calldata data
    ) external {
        if (tokenIds.length == 0) revert EmptyArray();
        IFlashAirdropReceiver receiver = IFlashAirdropReceiver(receiverAddress);
        for (uint256 i; i < tokenIds.length; ) {
            if (!hasDepositedNFT(msg.sender, nftAddress, tokenIds[i]))
                revert InvalidNFT();
            IERC721(nftAddress).safeTransferFrom(
                address(this),
                receiverAddress,
                tokenIds[i]
            );
            unchecked {
                ++i;
            }
        }
        if (!receiver.onFlashLoan(msg.sender, nftAddress, tokenIds, data))
            revert FlashAirdropFailed();

        for (uint256 i; i < tokenIds.length; ) {
            IERC721(nftAddress).safeTransferFrom(
                receiverAddress,
                address(this),
                tokenIds[i]
            );
            unchecked {
                ++i;
            }
        }
        emit FlashAirdropSuccess(msg.sender, nftAddress, tokenIds, data);
    }

     function canLiquidateNFT(
        address account,
        address nftAddress,
        uint256 tokenId
    ) public view {
        if (healthFactor(account) >= MIN_HEALTH_FACTOR)
            revert BorrowerIsSolvant();
        PoolStructs.LiquidateWarn storage warning = nftLiquidationWarning[
            account
        ][nftAddress][tokenId];
        if (warning.liquidator == address(0)) revert NoLiquidateWarn();
        if (block.timestamp <= warning.liquidationTimestamp)
            revert WarningDelayHasNotPassed();
        if (
            block.timestamp <=
            warning.liquidationTimestamp + NFT_LIQUIDATOR_DELAY &&
            msg.sender != warning.liquidator
        ) revert LiquidatorDelayHasNotPassed();
    }


    /*//////////////////////////////////////////////////////////////
                        Getters functions
    //////////////////////////////////////////////////////////////*/

     function getUserData(
        address user
    )
        public
        view
        returns (
            uint256 totalTokenCollateral,
            uint256 totalNFTCollateral,
            uint256 totalBorrowValue
        )
    {
        totalTokenCollateral = getUserTotalTokenCollateral(user);
        totalNFTCollateral = getUserNFTCollateralValue(user);
        totalBorrowValue = getUserTotalBorrow(user);
    }


        function getUserTotalTokenCollateral(
        address user
    ) public view returns (uint256 totalValueUSD) {
        uint256 len = supportedERC20s.length;
        for (uint256 i; i < len; ) {
            address token = supportedERC20s[i];
            uint256 tokenAmount = vaults[token].totalAsset.toAmount(
                userShares[user][token].collateral,
                false
            );
            if (tokenAmount != 0) {
                totalValueUSD += getAmountInUSD(token, tokenAmount);
            }
            unchecked {
                ++i;
            }
        }
    }

     function getUserNFTCollateralValue(
        address user
    ) public view returns (uint256 totalValueUSD) {
        uint256 len = supportedNFTs.length;
        for (uint256 i; i < len; ) {
            address nftAddress = supportedNFTs[i];
            uint256 userDepositedNFTs = getDepositedNFTCount(user, nftAddress);
            if (userDepositedNFTs != 0) {
                uint256 nftFloorPrice = getTokenPrice(nftAddress);
                totalValueUSD += nftFloorPrice * userDepositedNFTs;
            }
            unchecked {
                ++i;
            }
        }
    }

     function getUserTotalBorrow(
        address user
    ) public view returns (uint256 totalValueUSD) {
        uint256 len = supportedERC20s.length;
        for (uint256 i; i < len; ) {
            address token = supportedERC20s[i];
            uint256 tokenAmount = vaults[token].totalBorrow.toAmount(
                userShares[user][token].borrow,
                false
            );
            if (tokenAmount != 0) {
                totalValueUSD += getAmountInUSD(token, tokenAmount);
            }
            unchecked {
                ++i;
            }
        }
    }

     function getUserTokenCollateralAndBorrow(
        address user,
        address token
    )
        external
        view
        returns (uint256 tokenCollateralShare, uint256 tokenBorrowShare)
    {
        tokenCollateralShare = userShares[user][token].collateral;
        tokenBorrowShare = userShares[user][token].borrow;
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

      function getAmountInUSD(
        address token,
        uint256 amount
    ) public view returns (uint256 value) {
        uint256 price = getTokenPrice(token);
        uint8 decimals = token.tokenDecimals();
        uint256 amountIn18Decimals = amount * 10 ** (18 - decimals);
        // return USD value scaled by 18 decimals
        value = (amountIn18Decimals * price) / PRECISION;
    }


    function getTokenVault(
        address token
    ) public view returns (PoolStructs.TokenVault memory vault) {
        vault = vaults[token];
    }

     function getNFTLiquidationWarning(
        address account,
        address nft,
        uint256 tokenId
    ) external view returns (PoolStructs.LiquidateWarn memory) {
        return nftLiquidationWarning[account][nft][tokenId];
    }


     function amountToShares(
        address token,
        uint256 amount,
        bool isAsset
    ) external view returns (uint256 shares) {
        if (isAsset) {
            shares = uint256(vaults[token].totalAsset.toShares(amount, false));
        } else {
            shares = uint256(vaults[token].totalBorrow.toShares(amount, false));
        }
    }

     function sharesToAmount(
        address token,
        uint256 shares,
        bool isAsset
    ) external view returns (uint256 amount) {
        if (isAsset) {
            amount = uint256(vaults[token].totalAsset.toAmount(shares, false));
        } else {
            amount = uint256(vaults[token].totalBorrow.toAmount(shares, false));
        }
    }


     function maxFlashLoan(
        address token
    ) public view returns (uint256 maxFlashloanAmount) {
        maxFlashloanAmount = pausedStatus(token) ? 0 : type(uint256).max;
    }


     function flashFee(
        address token,
        uint256 amount
    ) public view returns (uint256) {
        return (amount * vaults[token].vaultInfo.flashFeeRate) / BPS;
    }


       /*//////////////////////////////////////////////////////////////
                            Owner functions
    //////////////////////////////////////////////////////////////*/



      function setupVault(
        address token,
        address priceFeed,
        PoolStructs.TokenType tokenType,
        PoolStructs.VaultSetupParams memory params,
        bool addToken
    ) external onlyOwner {
        _setupVault(token, priceFeed, tokenType, params, addToken);
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

        // If there are no borrows or vault or system is paused, no interest accrues
        if (_vault.totalBorrow.shares == 0 || pausedStatus(token)) {
            _currentRateInfo.lastTimestamp = uint64(block.timestamp);
            _currentRateInfo.lastBlock = uint64(block.number);
            _vault.vaultInfo = _currentRateInfo;
        } else {
            uint256 _deltaTime = block.number - _currentRateInfo.lastBlock;
            uint256 _utilization = (_vault.totalBorrow.amount * PRECISION) /
                _vault.totalAsset.amount;
            // Calculate new interest rate
            uint256 _newRate = _currentRateInfo.calculateInterestRate(
                _utilization
            );
            _currentRateInfo.ratePerSec = uint64(_newRate);
            _currentRateInfo.lastTimestamp = uint64(block.timestamp);
            _currentRateInfo.lastBlock = uint64(block.number);

            emit UpdateInterestRate(_deltaTime, uint64(_newRate));

            // Calculate interest accrued
            _interestEarned =
                (_deltaTime *
                    _vault.totalBorrow.amount *
                    _currentRateInfo.ratePerSec) /
                (PRECISION * BLOCKS_PER_YEAR);

            // Accumulate interest and fees
            _vault.totalBorrow.amount += uint128(_interestEarned);
            _vault.totalAsset.amount += uint128(_interestEarned);
            _vault.vaultInfo = _currentRateInfo;
            if (_currentRateInfo.feeToProtocolRate > 0) {
                _feesAmount =
                    (_interestEarned * _currentRateInfo.feeToProtocolRate) /
                    BPS;
                _feesShare =
                    (_feesAmount * _vault.totalAsset.shares) /
                    (_vault.totalAsset.amount - _feesAmount);
                _vault.totalAsset.shares += uint128(_feesShare);

                // accrue protocol fee shares to this contract
                userShares[address(this)][token].collateral += _feesShare;
            }
            emit AccruedInterest(
                _currentRateInfo.ratePerSec,
                _interestEarned,
                _feesAmount,
                _feesShare
            );
        }
        // save to storage
        vaults[token] = _vault;
    }

     function _setupVault(
        address token,
        address priceFeed,
        PoolStructs.TokenType tokenType,
        PoolStructs.VaultSetupParams memory params,
        bool addToken
    ) internal {
        if (addToken) {
            addSupportedToken(token, priceFeed, tokenType);
        } else {
            // cannot change vault setup when nor system or vault are paused
            WhenPaused(token);
        }
        if (tokenType == PoolStructs.TokenType.ERC20) {
            if (params.reserveRatio > BPS)
                revert InvalidReserveRatio(params.reserveRatio);
            if (params.feeToProtocolRate > MAX_PROTOCOL_FEE)
                revert InvalidFeeRate(params.feeToProtocolRate);
            if (params.flashFeeRate > MAX_PROTOCOL_FEE)
                revert InvalidFeeRate(params.flashFeeRate);
            PoolStructs.VaultInfo storage _vaultInfo = vaults[token].vaultInfo;
            _vaultInfo.reserveRatio = params.reserveRatio;
            _vaultInfo.feeToProtocolRate = params.feeToProtocolRate;
            _vaultInfo.flashFeeRate = params.flashFeeRate;
            _vaultInfo.optimalUtilization = params.optimalUtilization;
            _vaultInfo.baseRate = params.baseRate;
            _vaultInfo.slope1 = params.slope1;
            _vaultInfo.slope2 = params.slope2;

            emit NewVaultSetup(token, params);
        }
    }

}