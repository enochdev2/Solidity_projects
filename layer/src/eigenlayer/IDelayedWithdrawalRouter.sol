// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

/// @author https://github.com/Layr-Labs/eigenlayer-contracts/blob/mainnet/src/contracts/pods/DelayedWithdrawalRouter.sol
interface IDelayedWithdrawalRouter {
    struct DelayedWithdrawal {
        uint224 amount;
        uint32 blockCreated;
    }

    struct UserDelayedWithdrawals {
        uint256 delayedWithdrawalsCompleted;
        DelayedWithdrawal[] delayedWithdrawals;
    }

    function getClaimableUserDelayedWithdrawals(address user) external view returns (DelayedWithdrawal[] calldata);

    function userWithdrawals(address user) external view returns (UserDelayedWithdrawals calldata);

    function claimDelayedWithdrawals(uint256 maxNumberOfDelayedWithdrawalsToClaim) external;
}
