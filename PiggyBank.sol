// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract PiggyBank{
    event Deposit(uint deposit);
    event Withdraw(uint deposit);

    address owner = msg.sender;
     receive() external payable {
        emit Deposit(msg.value);
      }

      function withdraw()external{
        require(msg.sender == owner, 'not owner');
        emit Withdraw(address(this).balance);
        selfdestruct(payable(msg.sender));
      }
}