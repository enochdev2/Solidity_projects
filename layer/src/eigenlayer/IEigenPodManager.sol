// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

/// @author https://github.com/Layr-Labs/eigenlayer-contracts/blob/mainnet/src/contracts/pods/EigenPodManager.sol
interface IEigenPodManager {
    function createPod() external returns (address);

    function delegationManager() external view returns (address);

    function stake(bytes calldata pubkey, bytes calldata signature, bytes32 depositDataRoot) external payable;
}
