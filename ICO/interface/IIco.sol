// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

interface IICO{

    function updatePrice(uint256 price) external;

    function buy() external payable;

    function withdrawETH() external;

    function withdrawToken() external;

}