// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Test.sol";
import {Owned} from "src/libraries/Owned.sol";

contract MockOwned is Owned {
    constructor(address owner_, address operator_) Owned(owner_, operator_) {}

    function onlyOperatorFunction() external view onlyOperator returns (bool) {
        return true;
    }
}

contract OwnedTest is Test {
    MockOwned owned;

    address owner = address(1);
    address operator = address(2);

    event NewOwner(address indexed oldOwner, address indexed newOwner);
    event NominatedOwner(address indexed nominatedOwner);
    event NewOperator(address indexed oldOperator, address indexed newOperator);

    function setUp() public {
        owned = new MockOwned(owner, operator);
    }

    function test_onlyOperator() public {
        vm.prank(owner);
        assertTrue(owned.onlyOperatorFunction());

        vm.prank(operator);
        assertTrue(owned.onlyOperatorFunction());

        vm.expectRevert(Owned.Unauthorized.selector);
        vm.prank(address(3));
        owned.onlyOperatorFunction();
    }

    function test_setOperator() public {
        assertEq(owned.operator(), operator);
        vm.prank(operator);
        assertTrue(owned.onlyOperatorFunction());

        address newOperator = address(3);

        vm.expectRevert(Owned.ZeroAddress.selector);
        vm.prank(owner);
        owned.setOperator(address(0));

        vm.expectRevert(Owned.Unauthorized.selector);
        owned.setOperator(newOperator);

        vm.expectEmit();
        emit NewOperator(operator, newOperator);
        vm.prank(owner);
        owned.setOperator(newOperator);

        vm.expectRevert(Owned.Unauthorized.selector);
        vm.prank(operator);
        owned.onlyOperatorFunction();

        vm.prank(newOperator);
        assertTrue(owned.onlyOperatorFunction());
    }

    function test_nominateOwner() public {
        assertEq(owned.nominatedOwner(), address(0));

        address newOwner = address(3);

        vm.expectRevert(Owned.Unauthorized.selector);
        owned.nominateOwner(newOwner);

        vm.expectEmit();
        emit NominatedOwner(newOwner);
        vm.prank(owner);
        owned.nominateOwner(newOwner);

        vm.expectRevert(Owned.Unauthorized.selector);
        owned.acceptOwnership();

        vm.expectEmit();
        emit NewOwner(owner, newOwner);
        vm.prank(newOwner);
        owned.acceptOwnership();

        assertEq(owned.owner(), newOwner);
        assertEq(owned.nominatedOwner(), address(0));
    }
}
