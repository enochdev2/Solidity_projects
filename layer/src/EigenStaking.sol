// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.20;

import {IBeacon} from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {ReentrancyGuard} from "solmate/utils/ReentrancyGuard.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {IEigenUser} from "src/interfaces/IEigenUser.sol";
import {IEigenStakingEvents} from "src/interfaces/IEigenStakingEvents.sol";
import {Owned} from "src/libraries/Owned.sol";

contract EigenStaking is IBeacon, IEigenStakingEvents, Pausable, ReentrancyGuard, Owned {
    using FixedPointMathLib for uint256;

    struct DepositData {
        bytes pubkey;
        bytes signature;
        bytes32 deposit_data_root;
    }

    /// @notice EigenPodManager address.
    address public immutable eigenPodManager;
    /// @notice Stakewithus treasury which receives share of rewards.
    address public treasury;
    /// @notice One-time fee for creating a new validator.
    uint256 public oneTimeFee;
    /// @notice Performance fee percentage from execution layer rewards / `FEE_BASIS`, // i.e. 10_000 represents 100%.
    uint256 public executionFee;
    /// @notice Performance fee percentage from EigenLayer rewards / `FEE_BASIS`, // i.e. 10_000 represents 100%.
    uint256 public restakingFee;
    /// @notice Delay before a user can initiate a refund of pending unstaked ETH.
    uint256 public refundDelay;
    /// @notice Total number pending unstaked deposits across all users.
    uint256 public totalPendingValidators;
    /// @notice Implementation contract for deployed EigenUsers.
    address public implementation;

    /// @notice Mapping of users to EigenUser proxies which users manage their EigenPods and claim rewards from.
    mapping(address => address) public registry;
    /// @notice Mapping of users to number of pending unstaked deposits for that user.
    mapping(address => uint256) public pendingValidators;
    /// @notice Mapping of users to timestamp of their last deposit.
    mapping(address => uint256) public lastDepositTimestamps;

    uint256 internal constant _DEPOSIT_AMOUNT = 32 ether;
    uint256 internal constant _MAXIMUM_REFUND_DELAY = 7 days;
    uint256 public constant FEE_BASIS = 10_000;

    error InvalidAmount();
    error InvalidLength();
    error PendingValidators();
    error NoDeposit();
    error BeforeRefundDelay();
    error SameValue();
    error InvalidImplementation(address);

    constructor(
        address owner_,
        address operator_,
        address eigenPodManager_,
        address treasury_,
        uint256 oneTimeFee_,
        uint256 executionFee_,
        uint256 restakingFee_,
        uint256 refundDelay_,
        address implementation_
    ) Owned(owner_, operator_) {
        if (eigenPodManager_ == address(0)) revert ZeroAddress();
        eigenPodManager = eigenPodManager_;

        _setTreasury(treasury_);
        _setOneTimeFee(oneTimeFee_);
        _setExecutionFee(executionFee_);
        _setRestakingFee(restakingFee_);
        _setRefundDelay(refundDelay_);
        _setImplementation(implementation_);
    }

    /// @dev Costs less gas than `deposit()` if user if depositing for their own address.
    receive() external payable {
        _deposit(msg.sender);
    }

    /*//////////////////////////////////////
             PUBLIC FUNCTIONS
    //////////////////////////////////////*/

    function calculateExecutionFee(uint256 amount_) external view returns (uint256) {
        return amount_.mulDivDown(executionFee, FEE_BASIS);
    }

    function calculateRestakingFee(uint256 amount_) external view returns (uint256) {
        return amount_.mulDivDown(restakingFee, FEE_BASIS);
    }

    /**
     * @notice Deposits ETH into this contract for Stakewithus to create a new validator node on user's behalf.
     * @param user_ User's withdrawal address which receives consensus rewards and can claim execution layer rewards.
     * @dev `msg.value` must be a multiple of `_DEPOSIT_AMOUNT (32 ether) + oneTimeFee`
     */
    function deposit(address user_) external payable {
        _deposit(user_);
    }

    function _deposit(address user_) internal whenNotPaused nonReentrant {
        if (user_ == address(0)) revert ZeroAddress();
        if (pendingValidators[user_] > 0) revert PendingValidators();

        uint256 perValidator = _DEPOSIT_AMOUNT + oneTimeFee;
        if (msg.value == 0 || msg.value % perValidator != 0) revert InvalidAmount();

        // Deploy User proxy for address if it's their first deposit.
        if (registry[user_] == address(0)) {
            address eigenUser = address(
                new BeaconProxy(
                    address(this),
                    abi.encodeWithSignature("initialize(address,address)", user_, eigenPodManager)
                )
            );
            registry[user_] = eigenUser;
            emit UserRegistered(user_, eigenUser);
        }

        uint256 validators = msg.value / perValidator;

        pendingValidators[user_] += validators;
        totalPendingValidators += validators;
        lastDepositTimestamps[user_] = block.timestamp;

        emit Deposit(msg.sender, user_, validators);
    }

    /**
     * @notice Refunds unstaked ETH to user. User must wait for at least `refundDelay` after depositing before
     * initiating a refund.
     */
    function refund() external nonReentrant {
        uint256 validators = pendingValidators[msg.sender];
        if (block.timestamp < lastDepositTimestamps[msg.sender] + refundDelay) revert BeforeRefundDelay();

        _refund(msg.sender, validators);
    }

    /*////////////////////////////////////////
             OPERATOR FUNCTIONS
    ////////////////////////////////////////*/

    function stake(address user_, DepositData[] memory data_) external onlyOperator {
        uint256 length = data_.length;
        if (length == 0) revert InvalidLength();

        // This underflows, throwing an error if length > pendingValidators[user_]
        pendingValidators[user_] -= length;
        totalPendingValidators -= length;

        if (oneTimeFee > 0) SafeTransferLib.safeTransferETH(treasury, length * oneTimeFee);

        bytes[] memory pubkeys = new bytes[](length);

        IEigenUser eigenUser = IEigenUser(registry[user_]);

        for (uint256 i = 0; i < length; ++i) {
            bytes memory pubkey = data_[i].pubkey;

            eigenUser.stake{value: _DEPOSIT_AMOUNT}({
                pubkey: pubkey,
                signature: data_[i].signature,
                depositDataRoot: data_[i].deposit_data_root
            });

            pubkeys[i] = pubkey;
        }

        emit Staked(user_, pubkeys);
    }

    function refundUser(address user_, uint256 validators_) external onlyOperator {
        _refund(user_, validators_);
    }

    function pause() external onlyOperator {
        _pause();
    }

    function unpause() external onlyOperator {
        _unpause();
    }

    /*/////////////////////////////////////
             OWNER FUNCTIONS
    /////////////////////////////////////*/

    function setOneTimeFee(uint256 oneTimeFee_) external onlyOwner {
        if (oneTimeFee_ == oneTimeFee) revert SameValue();
        _setOneTimeFee(oneTimeFee_);
    }

    function setExecutionFee(uint256 executionFee_) external onlyOwner {
        if (executionFee_ == executionFee) revert SameValue();
        _setExecutionFee(executionFee_);
    }

    function setRestakingFee(uint256 restakingFee_) external onlyOwner {
        if (restakingFee_ == restakingFee) revert SameValue();
        _setRestakingFee(restakingFee_);
    }

    function setTreasury(address treasury_) external onlyOwner {
        if (treasury_ == address(0)) revert ZeroAddress();
        if (treasury_ == treasury) revert SameValue();
        _setTreasury(treasury_);
    }

    function setRefundDelay(uint256 refundDelay_) external onlyOwner {
        if (refundDelay_ == refundDelay) revert SameValue();
        _setRefundDelay(refundDelay_);
    }

    function setImplementation(address implementation_) external onlyOwner {
        _setImplementation(implementation_);
    }

    /*////////////////////////////////////////
             INTERNAL FUNCTIONS
    ////////////////////////////////////////*/

    function _refund(address user_, uint256 validators_) internal {
        if (validators_ == 0) revert NoDeposit();

        // This underflows, throwing an error if validators_ > pendingValidators[user_]
        pendingValidators[user_] -= validators_;
        totalPendingValidators -= validators_;

        SafeTransferLib.safeTransferETH(user_, validators_ * (_DEPOSIT_AMOUNT + oneTimeFee));
        emit Refund(user_, validators_);
    }

    /**
     * @dev One-time fee cannot be adjusted while there are still pending validators. Pause contract and stake/refund
     * all pending validators before changing one-time fee.
     */
    function _setOneTimeFee(uint256 oneTimeFee_) internal {
        if (totalPendingValidators != 0) revert PendingValidators();
        oneTimeFee = oneTimeFee_;
        emit OneTimeFeeSet(oneTimeFee_);
    }

    function _setExecutionFee(uint256 executionFee_) internal {
        if (executionFee_ > FEE_BASIS) revert InvalidAmount();
        executionFee = executionFee_;
        emit ExecutionFeeSet(executionFee_);
    }

    function _setRestakingFee(uint256 restakingFee_) internal {
        if (restakingFee_ > FEE_BASIS) revert InvalidAmount();
        restakingFee = restakingFee_;
        emit RestakingFeeSet(restakingFee_);
    }

    function _setTreasury(address treasury_) internal {
        emit NewTreasury(treasury, treasury_);
        treasury = treasury_;
    }

    function _setRefundDelay(uint256 refundDelay_) internal {
        if (refundDelay_ > _MAXIMUM_REFUND_DELAY) revert InvalidAmount();
        refundDelay = refundDelay_;
        emit RefundDelaySet(refundDelay_);
    }

    function _setImplementation(address implementation_) internal {
        if (implementation_.code.length == 0) revert InvalidImplementation(implementation_);
        implementation = implementation_;
        emit ImplementationSet(implementation_);
    }
}
