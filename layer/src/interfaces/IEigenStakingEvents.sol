// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IEigenStakingEvents {
    event UserRegistered(address indexed user, address indexed eigenUser);
    event Deposit(address indexed from, address indexed user, uint256 validators);
    event Staked(address indexed user, bytes[] pubkeys);
    event Refund(address indexed user, uint256 validators);
    event OneTimeFeeSet(uint256);
    event ExecutionFeeSet(uint256);
    event RestakingFeeSet(uint256);
    event NewTreasury(address indexed oldTreasury, address indexed newTreasury);
    event RefundDelaySet(uint256);
    event ImplementationSet(address);
}
