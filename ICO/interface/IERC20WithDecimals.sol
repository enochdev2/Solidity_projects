// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20WithDecimals is IERC20 {
    /**
     * @dev Returns the decimals of tokens.
     */
    function decimals() external view returns (uint8);
}