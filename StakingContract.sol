// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './IERC20.sol';

contract StakingContract{
IERC20 public immutable stakingToken;
IERC20 public immutable rewardToken;

address public owner;

uint public duration;
uint public finishAt;
uint public updatedAt;
uint public rewardRate;
uint public rewardPerTokenStored;
mapping (address => uint) public userRewardPerTokenPaid;
mapping (address => uint) rewards;

uint public totalSupply;
mapping (address => uint) public balanceOf;

modifier onlyOwner {
    require(msg.sender == owner, " not owner");
    _;
    
}

modifier updatedReward(address _account){
    rewardPerTokenStored = rewardPerToken();
    updatedAt = lastTimieRewardApplicable();

    if (_account != address(0)){
        rewards[_account] = earned(_account);
        userRewardPerTokenPaid[_account] = rewardPerTokenStored;  
    }
    _;
}

constructor(address _stakingToken, address _rewardToken) {
    owner = msg.sender; 
    stakingToken = IERC20(_stakingToken);
    rewardToken = IERC20(_rewardToken);
}

function setRewardsDuraction(uint _duration) external onlyOwner {
    require(finishAt < block.timestamp, "reward duration not finished");
   duration = _duration;
}


function notifyRewardAmount( uint _amount ) external  onlyOwner updatedReward(address(0)){
    if(block.timestamp > finishAt){
        rewardRate = _amount/ duration;

    }else {
        uint remainingRewards = rewardRate * (finishAt - block.timestamp );
        rewardRate = (remainingRewards + _amount ) / duration;
    }
    require(rewardRate > 0, "reward rate = 0");
     require(rewardRate * duration <= rewardToken.balanceOf(address(this)), "reward amount > balance");

    finishAt = block.timestamp + duration;
     updatedAt = block.timestamp;

}


function stake(uint _amount) external updatedReward(msg.sender) {
 require(_amount > 0 ,"amount = 0");
 stakingToken.transferFrom(msg.sender, address(this), _amount);
 balanceOf[msg.sender] += _amount;
 totalSupply += _amount;
}

function withdraw(uint _amount) external updatedReward(msg.sender) {
    require(_amount > 0, "amount = 0");
    balanceOf[msg.sender] -= _amount;
    totalSupply -= _amount;
    stakingToken.transfer(msg.sender, _amount);
    
}

function lastTimieRewardApplicable() public view returns (uint){
    return  _min(block.timestamp, finishAt);
}

function rewardPerToken () public view returns (uint){
    if(totalSupply == 0) {
     return rewardPerTokenStored;
    }
    return rewardPerTokenStored + (rewardRate * (lastTimieRewardApplicable() - updatedAt) * 1e18 ) / totalSupply;
}


function earned(address _account) public view returns(uint){
    return (balanceOf[_account] * (rewardPerToken() - userRewardPerTokenPaid[_account])) / 1e18 + rewards[_account];
}



function getReward()external updatedReward(msg.sender){
         uint reward = rewards[msg.sender];
         if( reward > 0){
            rewards[msg.sender] = 0;
            rewardToken.transfer(msg.sender, reward);
         }
}

function _min(uint x, uint y) private pure returns (uint) {
    return x <= y ? x : y;
}


}