// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


contract MultiSig{

    event Deposit(address indexed from, uint value);
    event Submit(uint indexed txId);
    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
    }

    modifier onlyOwner() {
        require(isOwner[msg.sender],"not an owner");
        _;
    }
    modifier txExist(uint txId){
        require(txId < transactions.length, "does not exist");
        _;
    }
    
    modifier notApproved(uint txId) {
        require(!approved[txId][msg.sender],"already approved");
        _;
    }

    modifier notExecuted(uint txId) {
        require(!transactions[txId].executed,"already executed");
        _;
    }

    address[] public owners;
    uint numCofirmatoinrequired;
    mapping(address => bool) public isOwner;
    mapping(uint => mapping(address => bool)) public approved;
    Transaction[] public transactions;

    constructor(address[] memory _owners, uint _numConfirmationsRequired){
        require(_owners.length>0, "invalid owners address ");
        require(_numConfirmationsRequired>0,"it must be more than 1 signatory");

        for(uint i; i<_owners.length; i++){
         address owner = _owners[i];

         require(owner != address(0), "invalid owner");
         require(!isOwner[owner], "owner is not unique");
         isOwner[owner]= true;
         owners.push(owner);

        }
         numCofirmatoinrequired = _numConfirmationsRequired;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }



    function submit(address _to, uint _value, bytes calldata _data) external onlyOwner {
     transactions.push(Transaction({
        to: _to,
        value: _value,
        data: _data,
        executed: false
     }));    
  emit Submit(transactions.length - 1);
    }
    
    function approval(uint txId) external txExist(txId) notApproved(txId) notExecuted(txId) {
        approved[txId][msg.sender] = true;
    }
 

    function getApprovedCount(uint txId) private view returns (uint count) {
        for(uint i; i < owners.length; i++) {
            if(approved[txId][owners[i]]){
                count +=1;
            }
        }
    }

    function executed(uint txId) external txExist(txId) notExecuted(txId) {
        require(getApprovedCount(txId) >= numCofirmatoinrequired, "approval < required");
        Transaction storage transaction = transactions[txId];
        transaction.executed = true;
        (bool success,)= transaction.to.call{value: transaction.value}(transaction.data);
        require(success, "tx failed");
    }


}