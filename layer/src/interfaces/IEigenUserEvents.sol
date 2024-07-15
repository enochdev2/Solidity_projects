// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IEigenUserEvents {
    event ClaimETH(uint256 amount);
    event TreasuryClaim(uint256 amount);
    event ClaimTokens(address token, uint256 user, uint256 treasury);
}
