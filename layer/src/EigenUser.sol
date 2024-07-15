// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.20;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {IDelayedWithdrawalRouter} from "src/eigenlayer/IDelayedWithdrawalRouter.sol";
import {IDelegationManager} from "src/eigenlayer/IDelegationManager.sol";
import {IEigenPod} from "src/eigenlayer/IEigenPod.sol";
import {IEigenPodManager} from "src/eigenlayer/IEigenPodManager.sol";
import {IEigenUser} from "src/interfaces/IEigenUser.sol";
import {IEigenUserEvents} from "src/interfaces/IEigenUserEvents.sol";
import {IEigenStaking} from "src/interfaces/IEigenStaking.sol";

/**
 * @notice Contract layer for users to manage their EigenPods and claim rewards. Also the `fee_recipient` for all
 * validators belonging to a user to receive execution layer rewards.
 * @dev Upgradeable BeaconProxy implementation contract as EigenPods are upgradeable.
 */
contract EigenUser is IEigenUser, IEigenUserEvents, Initializable {
    using SafeERC20 for IERC20;

    IEigenStaking public staking;
    address public user;

    /// @dev No longer needed post-initialization but stored in case future upgrades need this.
    IEigenPodManager public eigenPodManager;
    IEigenPod public eigenPod;
    IDelegationManager public delegationManager;
    IDelayedWithdrawalRouter public delayedWithdrawalRouter;

    /// @dev Unclaimed ETH in this smart contract that fully belongs to user.
    uint256 internal _userETH;
    /// @dev ETH in this smart contract that belongs to Stakewithus.
    uint256 internal _treasuryETH;
    /// @dev ETH still in EigenLayer withdrawal queue that belongs to Stakewithus.
    uint256 internal _queuedTreasuryETH;

    error Unauthorized();
    error NothingToClaim();

    receive() external payable {}

    /*//////////////////////////////////////
             INITIALIZER
    //////////////////////////////////////*/

    constructor() {
        _disableInitializers();
    }

    function initialize(address user_, address eigenPodManager_) external initializer {
        staking = IEigenStaking(payable(msg.sender));
        user = user_;
        eigenPodManager = IEigenPodManager(eigenPodManager_);
        eigenPod = IEigenPod(eigenPodManager.createPod());
        delegationManager = IDelegationManager(eigenPodManager.delegationManager());
        delayedWithdrawalRouter = IDelayedWithdrawalRouter(eigenPod.delayedWithdrawalRouter());
    }

    /*//////////////////////////////////////
             STAKING
    //////////////////////////////////////*/

    function stake(
        bytes calldata pubkey_,
        bytes calldata signature_,
        bytes32 depositDataRoot_
    ) external payable onlyStaking {
        eigenPodManager.stake{value: msg.value}(pubkey_, signature_, depositDataRoot_);
    }

    /**
     * @notice Verify staked validators have EigenPod set as withdrawal credentials using EigenLayer's Beacon Chain
     * oracle. Stakewithus bot operator will call this once the deposit is verified, but user also has the ability to
     * do so in the case that Stakewithus is no longer operational.
     * @dev Proofs are generated using: https://github.com/Layr-Labs/eigenpod-proofs-generation
     */
    function verifyWithdrawalCredentials(
        uint64 oracleTimestamp_,
        IEigenPod.StateRootProof calldata stateRootProof_,
        uint40[] calldata validatorIndices_,
        bytes[] calldata withdrawalCredentialProofs_,
        bytes32[][] calldata validatorFields_
    ) external onlyUserOrOperator {
        eigenPod.verifyWithdrawalCredentials(
            oracleTimestamp_,
            stateRootProof_,
            validatorIndices_,
            withdrawalCredentialProofs_,
            validatorFields_
        );
    }

    /*//////////////////////////////////////
             DELEGATION
    //////////////////////////////////////*/

    /// @notice Choose which EigenLayer operator user wishes to delegate restaked ETH to.
    function delegateTo(
        address operator_,
        IDelegationManager.SignatureWithExpiry memory approverSignatureAndExpiry_,
        bytes32 approverSalt_
    ) external onlyUser {
        delegationManager.delegateTo(operator_, approverSignatureAndExpiry_, approverSalt_);
    }

    /// @notice Undelegate from user's selected EigenLayer operator.
    function undelegate() external onlyUser {
        delegationManager.undelegate(address(this));
    }

    /// @notice Undelegate from user's selected EigenLayer operator and delegate to a new operator.
    function redelegate(
        address operator_,
        IDelegationManager.SignatureWithExpiry memory approverSignatureAndExpiry_,
        bytes32 approverSalt_
    ) external onlyUser {
        delegationManager.undelegate(address(this));
        delegationManager.delegateTo(operator_, approverSignatureAndExpiry_, approverSalt_);
    }

    /*//////////////////////////////////////
             QUEUE WITHDRAWAL
    //////////////////////////////////////*/

    /// @notice Queue withdrawal of EigenPod non-Beacon Chain ETH. Stakewithus also has access to this function so we
    /// can claim rewards in case user is not active.
    /// @dev We assume that non-Beacon Chain ETH in EigenPods are restaking rewards provided by EigenLayer operators.
    function queueRestakingRewards() external onlyUserOrOperator {
        uint256 eigenPodBalance = eigenPod.nonBeaconChainETHBalanceWei();
        if (eigenPodBalance == 0) revert NothingToClaim();

        eigenPod.withdrawNonBeaconChainETHBalanceWei(address(this), eigenPodBalance);

        // Earmark cut of restaking rewards belonging to Stakewithus treasury.
        _queuedTreasuryETH += staking.calculateRestakingFee(eigenPodBalance);
    }

    /*//////////////////////////////////////
             ETH CLAIMS
    //////////////////////////////////////*/

    /// @notice ETH in contract and claimable queue that belongs to user.
    function unclaimedETH() external view returns (uint256) {
        (uint256 userClaimableRewards, ) = _getCalculateClaimableRewards();
        (uint256 userContractETH, ) = calculateContractETH();
        return userClaimableRewards + userContractETH;
    }

    ///@notice Get amount of ETH in contract that belongs to user and treasury.
    function calculateContractETH() public view returns (uint256 toUser, uint256 toTreasury) {
        (toUser, toTreasury) = _calculateExecutionRewards();
        toUser += _userETH;
        toTreasury += _treasuryETH;
    }

    function claimETH(bool claimDelayedWithdrawals_) external onlyUser {
        // First, claim delayed withdrawals.
        if (claimDelayedWithdrawals_) _claimDelayedWithdrawals();

        (uint256 userContractETH, uint256 treasuryContractETH) = calculateContractETH();

        if (userContractETH == 0) revert NothingToClaim();

        // Next, process Stakewithus cut if there's anything to claim..
        if (treasuryContractETH > 0) _treasuryClaim();

        // Finally, process user's ETH.
        emit ClaimETH(address(this).balance);
        SafeTransferLib.safeTransferETH(user, address(this).balance);
    }

    function treasuryClaim(bool claimDelayedWithdrawals_) external onlyOperator {
        if (claimDelayedWithdrawals_) _claimDelayedWithdrawals();
        _treasuryClaim();
    }

    function _treasuryClaim() internal {
        (uint256 toUser, uint256 toTreasury) = _calculateExecutionRewards();
        uint256 amount = toTreasury + _treasuryETH;

        if (amount == 0) return; // Do nothing as treasury has nothing to claim.
        SafeTransferLib.safeTransferETH(staking.treasury(), amount);

        _userETH += toUser;
        _treasuryETH = 0;

        emit TreasuryClaim(amount);
    }

    function _claimDelayedWithdrawals() internal {
        IDelayedWithdrawalRouter.DelayedWithdrawal[] memory claimable = delayedWithdrawalRouter
            .getClaimableUserDelayedWithdrawals(address(this));
        if (claimable.length == 0) revert NothingToClaim();

        (uint256 toUser, uint256 toTreasury) = _calculateClaimableRewards(claimable);

        delayedWithdrawalRouter.claimDelayedWithdrawals(claimable.length);

        _userETH += toUser;
        _treasuryETH += toTreasury;
        _queuedTreasuryETH -= toTreasury;
    }

    function _getCalculateClaimableRewards() internal view returns (uint256 toUser, uint256 toTreasury) {
        IDelayedWithdrawalRouter.DelayedWithdrawal[] memory claimable = delayedWithdrawalRouter
            .getClaimableUserDelayedWithdrawals(address(this));

        return _calculateClaimableRewards(claimable);
    }

    function _calculateClaimableRewards(
        IDelayedWithdrawalRouter.DelayedWithdrawal[] memory claimable_
    ) internal view returns (uint256 toUser, uint256 toTreasury) {
        // First, calculate all claimable rewards under `toUser`.
        uint256 length = claimable_.length;
        for (uint256 i = 0; i < length; ++i) {
            toUser += claimable_[i].amount;
        }

        // If we have queued treasury rewards, transfer from `toUser` to `ToTreasury`.
        if (_queuedTreasuryETH == 0) return (toUser, toTreasury);

        // Limit fee collected in one claim tx to same ratio as Stakewithus restaking fee.
        uint256 limit = staking.calculateRestakingFee(toUser);
        toTreasury = _queuedTreasuryETH > limit ? limit : _queuedTreasuryETH;
        toUser -= toTreasury;
    }

    function _calculateExecutionRewards() internal view returns (uint256 toUser, uint256 toTreasury) {
        uint256 balance = address(this).balance - _userETH - _treasuryETH;
        toTreasury = staking.calculateExecutionFee(balance);
        toUser = balance - toTreasury;
    }

    /*//////////////////////////////////////
             ERC20 CLAIMS
    //////////////////////////////////////*/

    /// @dev Claim ERC20 tokens deposited in EigenPod or EigenUser (e.g. restaking rewards or airdrops).
    function claimTokens(address token_) external onlyUserOrOperator {
        IERC20 token = IERC20(token_);

        // First, claim from eigenPod if possible.
        uint256 eigenPodBalance = token.balanceOf(address(eigenPod));

        if (eigenPodBalance > 0) {
            IERC20[] memory tokenList = new IERC20[](1);
            tokenList[0] = token;
            uint256[] memory balanceList = new uint256[](1);
            balanceList[0] = eigenPodBalance;

            eigenPod.recoverTokens(tokenList, balanceList, address(this));
        }

        // Claim from this smart contract.
        uint256 balance = IERC20(token).balanceOf(address(this));

        if (balance == 0) revert NothingToClaim();

        uint256 fee = staking.calculateRestakingFee(balance);
        uint256 toUser = balance - fee;

        if (fee > 0) token.safeTransfer(staking.treasury(), fee);
        token.safeTransfer(user, toUser);

        emit ClaimTokens(address(token), toUser, fee);
    }

    /*//////////////////////////////////////
             MODIFIERS
    //////////////////////////////////////*/

    modifier onlyUser() {
        if (msg.sender != user) revert Unauthorized();
        _;
    }

    modifier onlyStaking() {
        if (msg.sender != address(staking)) revert Unauthorized();
        _;
    }

    modifier onlyUserOrOperator() {
        if (msg.sender != staking.operator() && msg.sender != user) revert Unauthorized();
        _;
    }

    modifier onlyOperator() {
        if (msg.sender != staking.operator()) revert Unauthorized();
        _;
    }
}
