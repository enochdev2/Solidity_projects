// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.20;

/// @dev Used by `EigenUser.sol`.
interface IEigenStaking {
    function calculateExecutionFee(uint256) external view returns (uint256);

    function calculateRestakingFee(uint256) external view returns (uint256);

    function treasury() external view returns (address);

    function operator() external view returns (address);
}
