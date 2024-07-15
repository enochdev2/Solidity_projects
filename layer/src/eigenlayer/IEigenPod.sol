// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @author https://github.com/Layr-Labs/eigenlayer-contracts/blob/mainnet/src/contracts/pods/EigenPod.sol
interface IEigenPod {
    struct StateRootProof {
        bytes32 beaconStateRoot;
        bytes proof;
    }

    function delayedWithdrawalRouter() external view returns (address);

    function nonBeaconChainETHBalanceWei() external view returns (uint256);

    function verifyWithdrawalCredentials(
        uint64 oracleTimestamp,
        StateRootProof calldata stateRootProof,
        uint40[] calldata validatorIndices,
        bytes[] calldata validatorFieldsProofs,
        bytes32[][] calldata validatorFields
    ) external;

    function withdrawNonBeaconChainETHBalanceWei(address recipient, uint256 amountToWithdraw) external;

    function recoverTokens(IERC20[] memory tokenList, uint256[] memory amountsToWithdraw, address recipient) external;
}
