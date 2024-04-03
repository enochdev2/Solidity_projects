// SPDX-License-Identifier: UNLICENSED

/**
 *Submitted for verification at BscScan.com on 2022-02-17
*/

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interface/IICO.sol";
import "./interface/IBunzz.sol";
import "./interface/IERC20WithDecimals.sol";

contract ICO is IICO, Ownable, IBunzz {

    IERC20WithDecimals public token; // ERC20 token
    uint256 public price; // Token price
    uint128 public startTime; // ICO start time
    uint128 public endTime; // ICO end time

    event UpdatePrice(address _executor, uint256 _price);
    event SetToken(address _executor, address _token);
    event Buy(address _buyer, uint256 _amount);

    constructor (uint128 _startTime, uint128 _endTime) {
        require(_endTime > _startTime, "ICO: time invalid");
        require(_startTime >= _getCurrentTime(), "ICO: startTime invalid ");
        require(_endTime > _getCurrentTime(), "ICO: endTime invalid");

        startTime = _startTime;
        endTime = _endTime;
    }

    function connectToOtherContracts(address[] calldata addresses) external override onlyOwner {
        require(addresses.length == 1, "ICO: invalid addresses");
        setToken(addresses[0]);
    }

    function setToken(address _token) internal {
        if (address(token) != address(0x0)) {
            require(address(token) != _token, "ICO: This token is already set");
            require(token.balanceOf(address(this)) == 0, "ICO: Withdraw token before change the address");
        }
        token = IERC20WithDecimals(_token);
        emit SetToken(msg.sender, _token);
    }

    function updatePrice(uint256 _price) external override onlyOwner {
        require(_price > 0, "ICO: Price invalid");
        price = _price;
        emit UpdatePrice(msg.sender, _price);
    }

    function buy() external payable override {
        require(address(token) != address(0x0), "ICO: Token is not set yet");
        require(price > 0, "ICO: Price is not set yet");
        require(_getCurrentTime() >= startTime, "ICO: ICO is not started");
        require(_getCurrentTime() <= endTime, "ICO: ICO is end");

        uint256 ethAmount = msg.value;
        require(ethAmount > 0, "ICO: ETH amount is invalid");
        uint256 tokenAmount = ethAmount * (10 ** token.decimals()) / price;
        require(token.balanceOf(address(this)) >= tokenAmount, "ICO: Token amount is not enough");
        token.transfer(msg.sender, tokenAmount);
        emit Buy(msg.sender, tokenAmount);
    }

    function withdrawETH() external override onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    function withdrawToken() external override onlyOwner {
        require(address(token) != address(0x0), "ICO: Token address is not set yet");
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    function _getCurrentTime() private view returns (uint128) {
        return uint128(block.timestamp);
    }
}