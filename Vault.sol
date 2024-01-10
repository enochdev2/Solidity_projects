// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC20.sol";

contract Vault{
  IERC20 public immutable token;
  uint public totalSupply;
  mapping(address=> uint) public balanceOf;

  constructor(address _token){
    token = IERC20(_token);
  }


  function _mint(address _recipient, uint _amount) private {
   totalSupply += _amount;
   balanceOf[_recipient] += _amount;
  }
  function _burn(address _recipient, uint _amount) private {
   totalSupply -= _amount;
   balanceOf[_recipient] -= _amount;
  }


  function deposit(uint _amount) external   {
    uint share;
    if(totalSupply == 0){
        share = _amount;
    }else {
        share = (_amount * totalSupply)/ token.balanceOf(address(this));
    }

    _mint(msg.sender, share);
    token.transferFrom(msg.sender, address(this), _amount);

  } 

  function withdraw(uint _share) external payable  {

   
    uint  amount = (_share * token.balanceOf(address(this))) / totalSupply;
    _burn(msg.sender, _share);
    token.transfer(msg.sender, amount);

  }


}