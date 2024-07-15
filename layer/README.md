# EigenLayer Staking Contracts

Stakewithus [ETH Staking Contracts](https://github.com/stakewithus/eth-staking-contracts/) with [EigenLayer](https://app.eigenlayer.xyz/) integration.

## EigenLayer

The main differences between native ETH staking and EigenLayer restaking are:

- Validator withdrawal credentials are set to to EigenLayer smart contracts
- Users verify ETH deposits and withdrawals by comparing proofs to EigenLayer's Beacon Chain oracle
- Users have the option to restake ETH to EigenLayer Operators for additional rewards

## Setup

### Installation

```shell
forge install
cp .env.sample .env # and fill in values
```

### Tests

```shell
forge test
```

### Scripts

```shell
source .env
forge script Script/Staking.s.sol:Deploy --rpc_url $RPC_HOLESKY --broadcast --verify # or RPC_MAINNET
```

## Notes

EigenLayer Beacon Chain ETH withdrawals are queued via [`verifyAndProcessWithdrawals()`](https://github.com/Layr-Labs/eigenlayer-contracts/blob/mainnet/src/contracts/pods/EigenPod.sol#L232), which is an unpermissioned function anyone can call with a valid proof.

### Dependencies

- [OpenZeppelin Contracts v5.0.2](https://github.com/OpenZeppelin/openzeppelin-contracts/tree/dbb6104ce834628e473d2173bbc9d47f81a9eec3)
- [OpenZeppelin Contracts Upgradeable v5.0.2](https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/tree/723f8cab09cdae1aca9ec9cc1cfa040c2d4b06c1)
- [Solmate](https://github.com/transmissions11/solmate/tree/c892309933b25c03d32b1b0d674df7ae292ba925)

### References

- [EigenLayer Contracts](https://github.com/Layr-Labs/eigenlayer-contracts)
- [EigenLayer Docs - Restaking Flows](https://github.com/Layr-Labs/eigenlayer-contracts/tree/dev/docs#common-user-flows)
- [EigenLayer Proofs Generation CLI](https://github.com/Layr-Labs/eigenpod-proofs-generation)
