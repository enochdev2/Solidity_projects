// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.20;

/// @dev Used by `EigenStaking.sol`.
interface IEigenUser {
    function stake(bytes calldata pubkey, bytes calldata signature, bytes32 depositDataRoot) external payable;
}
