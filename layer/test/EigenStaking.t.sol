// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {IEigenStakingEvents} from "src/interfaces/IEigenStakingEvents.sol";
import {Owned} from "src/libraries/Owned.sol";
import {EigenStaking} from "src/EigenStaking.sol";
import {EigenUser} from "src/EigenUser.sol";

contract StakingTest is Test, IEigenStakingEvents {
    EigenStaking staking;

    address user = makeAddr("user");
    address treasury = makeAddr("treasury");

    function setUp() public {
        vm.createSelectFork(vm.envString("RPC_HOLESKY"));

        EigenUser eigenUserImplementation = new EigenUser();

        staking = new EigenStaking({
            owner_: address(this),
            operator_: address(this),
            eigenPodManager_: 0x30770d7E3e71112d7A6b7259542D1f680a70e315,
            treasury_: treasury,
            oneTimeFee_: 1 ether,
            executionFee_: 2500, // 25%
            restakingFee_: 2500, // 25%
            refundDelay_: 0,
            implementation_: address(eigenUserImplementation)
        });

        vm.deal(user, type(uint248).max);
    }

    function test_deposit(uint8 validators_) public {
        vm.assume(validators_ > 0 && validators_ < 140);

        assertEq(staking.pendingValidators(user), 0);
        assertEq(staking.registry(user), address(0));

        vm.expectEmit(true, false, false, false);
        emit UserRegistered(user, address(0));
        vm.expectEmit();
        emit Deposit(user, user, validators_);
        vm.prank(user);
        staking.deposit{value: validators_ * 33 ether}(user);

        assertEq(staking.pendingValidators(user), validators_);
        assertEq(address(staking).balance, validators_ * 33 ether);

        // EigenUser was updated from address(0) to deployed contract.
        address payable eigenUser = payable(staking.registry(user));
        assertTrue(eigenUser != address(0));
        assertEq(EigenUser(eigenUser).user(), user);

        // Subsequent deposit reverts as user has pending validators.
        vm.expectRevert(EigenStaking.PendingValidators.selector);
        vm.prank(user);
        staking.deposit{value: 33 ether}(user);

        vm.prank(user);
        staking.refund();

        assertEq(staking.pendingValidators(user), 0);

        // User can deposit again if pending validators == 0.
        vm.expectEmit();
        emit Deposit(user, user, validators_);
        vm.prank(user);
        staking.deposit{value: validators_ * 33 ether}(user);

        // Fee recipient did not change on subsequent deposit.
        assertEq(eigenUser, staking.registry(user));
    }

    function test_receive(uint8 validators_) public {
        vm.assume(validators_ > 0 && validators_ < 100);

        assertEq(staking.pendingValidators(user), 0);
        assertEq(staking.registry(user), address(0));

        vm.expectEmit(true, false, false, false);
        emit UserRegistered(user, address(0));
        vm.expectEmit();
        emit Deposit(user, user, validators_);
        vm.prank(user);
        (bool success, ) = address(staking).call{value: validators_ * 33 ether}("");
        assertTrue(success);

        assertEq(staking.pendingValidators(user), validators_);
        assertEq(address(staking).balance, validators_ * 33 ether);
    }

    function test_deposit_reverts_if_zero_address() public {
        vm.expectRevert(Owned.ZeroAddress.selector);
        staking.deposit{value: 33 ether}(address(0));
    }

    function test_deposit_reverts_on_invalid_amount(uint256 amount_) public {
        vm.assume(amount_ % 33 ether != 0 && amount_ < type(uint240).max);
        vm.expectRevert(EigenStaking.InvalidAmount.selector);
        vm.prank(user);
        staking.deposit{value: amount_}(user);
    }

    function test_deposit_reverts_when_paused() public {
        staking.pause();

        vm.expectRevert(Pausable.EnforcedPause.selector);
        vm.prank(user);
        staking.deposit{value: 33 ether}(user);
    }

    function test_refund(uint8 validators_, uint256 oneTimeFee_) public {
        vm.assume(validators_ > 0 && validators_ < 140);
        vm.assume(oneTimeFee_ < 1 ether);

        staking.setOneTimeFee(oneTimeFee_);

        uint256 balance = address(user).balance;

        vm.prank(user);
        staking.deposit{value: validators_ * (32 ether + oneTimeFee_)}(user);
        vm.expectEmit();
        emit Refund(user, validators_);
        vm.prank(user);
        staking.refund();

        assertEq(balance, address(user).balance);
    }

    function test_refund_reverts_before_refund_delay() public {
        staking.setRefundDelay(3 days);

        uint256 balance = address(user).balance;

        vm.prank(user);
        staking.deposit{value: 33 ether}(user);
        vm.expectRevert(EigenStaking.BeforeRefundDelay.selector);
        vm.prank(user);
        staking.refund();

        assertEq(address(user).balance, balance - 33 ether);

        vm.warp(block.timestamp + 3 days + 1);
        vm.prank(user);
        staking.refund();

        assertEq(address(user).balance, balance);
    }

    function test_refund_reverts_if_no_pending_validators() public {
        vm.expectRevert(EigenStaking.NoDeposit.selector);
        vm.prank(user);
        staking.refund();

        vm.prank(user);
        staking.deposit{value: 33 ether}(user);

        vm.expectRevert(EigenStaking.NoDeposit.selector);
        staking.refundUser(user, 0);
    }

    function test_stake_reverts_if_invalid_length() public {
        vm.prank(user);
        staking.deposit{value: 33 ether}(user);

        EigenStaking.DepositData[] memory data = new EigenStaking.DepositData[](0);

        vm.expectRevert(EigenStaking.InvalidLength.selector);
        staking.stake(user, data);

        data = new EigenStaking.DepositData[](2);

        bytes32 root = "0";

        data[0] = EigenStaking.DepositData({pubkey: hex"00", signature: hex"00", deposit_data_root: root});
        data[1] = EigenStaking.DepositData({pubkey: hex"ff", signature: hex"ff", deposit_data_root: root});

        vm.expectRevert();
        staking.stake(user, data);
    }

    function test_setOneTimeFee_reverts_if_there_are_pending_validators() public {
        assertEq(staking.oneTimeFee(), 1 ether);

        vm.prank(user);
        staking.deposit{value: 33 ether}(user);

        assertGt(staking.totalPendingValidators(), 0);

        vm.expectRevert(EigenStaking.PendingValidators.selector);
        staking.setOneTimeFee(2 ether);

        assertEq(staking.oneTimeFee(), 1 ether);

        staking.refundUser(user, 1);

        assertEq(staking.totalPendingValidators(), 0);

        vm.expectEmit();
        emit OneTimeFeeSet(2 ether);
        staking.setOneTimeFee(2 ether);

        assertEq(staking.oneTimeFee(), 2 ether);
    }

    function test_setRefundDelay_cannot_exceed_maximum(uint256 amount_) public {
        vm.assume(amount_ > 0 && amount_ < type(uint240).max);

        vm.expectRevert(EigenStaking.InvalidAmount.selector);
        staking.setRefundDelay(7 days + amount_);
    }

    function test_setExecutionFee_cannot_exceed_maximum(uint256 amount_) public {
        vm.assume(amount_ > 0 && amount_ < type(uint240).max);

        vm.expectRevert(EigenStaking.InvalidAmount.selector);
        staking.setExecutionFee(10_000 + amount_);
    }

    function test_setRestakingFee_cannot_exceed_maximum(uint256 amount_) public {
        vm.assume(amount_ > 0 && amount_ < type(uint240).max);

        vm.expectRevert(EigenStaking.InvalidAmount.selector);
        staking.setRestakingFee(10_000 + amount_);
    }

    function test_setImplementation() public {
        address newImplementation = address(new EigenUser());

        vm.expectEmit();
        emit ImplementationSet(newImplementation);
        staking.setImplementation(newImplementation);
    }

    function test_setImplementation_fails_if_not_contract() public {
        address addr = address(3);

        vm.expectRevert(abi.encodeWithSelector(EigenStaking.InvalidImplementation.selector, addr));
        staking.setImplementation(addr);
    }
}
