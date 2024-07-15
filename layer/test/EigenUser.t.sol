// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Test.sol";

import {IDelegationManager} from "src/eigenlayer/IDelegationManager.sol";
import {IEigenUserEvents} from "src/interfaces/IEigenUserEvents.sol";
import {EigenStaking} from "src/EigenStaking.sol";
import {EigenUser} from "src/EigenUser.sol";
import {WithdrawalCredentialsProof} from "test/helpers/proofs/WithdrawalCredentialsProof.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

contract EigenUserTest is Test, IEigenUserEvents, WithdrawalCredentialsProof {
    using stdStorage for StdStorage;

    // Pre-deployed EigenStaking contract with created EigenPod for `user`.
    EigenStaking staking = EigenStaking(payable(0x2D99795a5fBa38B7936C93B9D6b3dE22dC2215b8));
    EigenUser eigenUser = EigenUser(payable(0x2843c7cdb600E47df28192b58634023BB1f58a31));
    address user = 0xabc46876f2831554a154Af0585F98A66832A68B0;

    address treasury = makeAddr("treasury");

    function setUp() public {
        vm.createSelectFork(vm.envString("RPC_HOLESKY"), 1363210);

        EigenUser eigenUserImplementation = new EigenUser();

        // These values don't matter, we're overriding bytecode, not storage.
        EigenStaking newStaking = new EigenStaking(
            address(this),
            address(this),
            address(1),
            treasury,
            0,
            0,
            0,
            0,
            address(eigenUserImplementation)
        );
        // Manually override pre-deployed staking bytecode with latest version of contract.
        vm.etch(0x2D99795a5fBa38B7936C93B9D6b3dE22dC2215b8, address(newStaking).code);

        // Setup new values.
        vm.startPrank(staking.owner());
        staking.setImplementation(address(eigenUserImplementation));
        staking.setRestakingFee(2500);
        staking.setExecutionFee(2500);
        staking.setTreasury(treasury);
        vm.stopPrank();

        stdstore.target(address(eigenUser)).sig("delayedWithdrawalRouter()").checked_write(
            eigenUser.eigenPod().delayedWithdrawalRouter()
        );

        vm.deal(address(this), type(uint248).max);
    }

    function test_delegation_flow() public {
        vm.prank(user);
        eigenUser.delegateTo(
            0xA4e245C3a1Cb2F0512a71B9CD908dCa2F1641781,
            IDelegationManager.SignatureWithExpiry({signature: "", expiry: 0}),
            0x0
        );

        vm.prank(user);
        eigenUser.redelegate(
            0x57b6FdEF3A23B81547df68F44e5524b987755c99,
            IDelegationManager.SignatureWithExpiry({signature: "", expiry: 0}),
            0x0
        );

        vm.prank(user);
        eigenUser.undelegate();
    }

    function test_verifyWithdrawalCredentials() public {
        vm.prank(user);
        eigenUser.verifyWithdrawalCredentials(
            WithdrawalCredentialsProof.oracleTimestamp,
            WithdrawalCredentialsProof.stateRootProof,
            WithdrawalCredentialsProof.validatorIndices,
            WithdrawalCredentialsProof.validatorFieldsProofs,
            WithdrawalCredentialsProof.validatorFields
        );
    }

    function test_queueRestakingRewards(uint256 amount_) public {
        vm.assume(amount_ > 0 && amount_ < type(uint224).max);

        uint256 treasuryBalance = address(treasury).balance;
        uint256 userBalance = address(user).balance;

        uint256 toTreasury = amount_ / 4;
        uint256 toUser = (amount_ - toTreasury);

        (bool sent, ) = address(eigenUser.eigenPod()).call{value: amount_}("");
        assertTrue(sent);

        vm.prank(user);
        eigenUser.queueRestakingRewards();

        // Changing restaking fee after claim doesn't affect previously calculated rewards.
        vm.prank(staking.owner());
        staking.setRestakingFee(5000);

        (sent, ) = address(eigenUser.eigenPod()).call{value: amount_}("");
        assertTrue(sent);

        vm.prank(user);
        eigenUser.queueRestakingRewards();

        // Second claim is calculated using new restaking fee.
        uint256 toTreasuryTwo = amount_ / 2;
        uint256 toUserTwo = (amount_ - toTreasuryTwo);

        assertEq(eigenUser.unclaimedETH(), 0);
        vm.roll(block.number + 21_001);
        assertEq(eigenUser.unclaimedETH(), toUser);

        // Tx fails if nothing to claim.
        vm.expectRevert(EigenUser.NothingToClaim.selector);
        vm.prank(user);
        eigenUser.claimETH(false);

        vm.prank(user);
        eigenUser.claimETH(true);

        assertEq(address(treasury).balance, treasuryBalance + toTreasury + toTreasuryTwo);
        assertEq(address(user).balance, userBalance + toUser + toUserTwo);
    }

    function test_queueRestakingRewards_reverts_if_nothing_to_queue() public {
        assertEq(address(eigenUser.eigenPod()).balance, 0);

        vm.expectRevert(EigenUser.NothingToClaim.selector);
        vm.prank(user);
        eigenUser.queueRestakingRewards();
    }

    function test_claimETH_reverts_if_nothing_to_claim() public {
        assertEq(eigenUser.unclaimedETH(), 0);

        vm.expectRevert(EigenUser.NothingToClaim.selector);
        vm.prank(user);
        eigenUser.claimETH(true);
    }

    function test_calculateContractETH(uint256 amount_) public {
        vm.assume(amount_ > 0 && amount_ < type(uint224).max);

        vm.deal(address(eigenUser), amount_);

        uint256 toTreasury = amount_ / 4;
        uint256 toUser = amount_ - toTreasury;

        (uint256 actualUser, uint256 actualTreasury) = eigenUser.calculateContractETH();

        assertEq(toUser, actualUser);
        assertEq(toTreasury, actualTreasury);
    }

    function test_claimTokens(uint256 amount_) public {
        vm.assume(amount_ > 0 && amount_ < type(uint128).max);

        MockERC20 token = new MockERC20("Mock ERC20", "MT");

        token.mint(address(eigenUser.eigenPod()), amount_);

        vm.prank(user);
        eigenUser.claimTokens(address(token));

        uint256 toTreasury = amount_ / 4;
        uint256 toUser = (amount_ - toTreasury);

        assertEq(token.balanceOf(treasury), toTreasury);
        assertEq(token.balanceOf(user), toUser);
    }

    function test_claimTokens_reverts_if_nothing_to_claim() public {
        MockERC20 token = new MockERC20("Mock ERC20", "MT");

        vm.expectRevert(EigenUser.NothingToClaim.selector);
        vm.prank(user);
        eigenUser.claimTokens(address(token));
    }
}
