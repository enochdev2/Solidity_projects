// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;


contract CrowdFunding{

    struct Campaign{
        address creator;
        uint goalTarget;
        uint pledge;
        uint startTime;
        uint endTime;
        bool claimed;
    }

    uint count;
    mapping(uint=>Campaign) public campaigns;
    mapping(uint=>mapping(address=>uint)) public pledgeAmount:


    function lunch(uint _goalTarget, uint _startTime, uint _endTime) external {
        require(_startTime >= block.timestamp,"start time must not be backdated");
        require(_endTime > _startTime,"end time must be more than start time");
        require(endTime <= block.timestamp + 9days, "invalid date");

        count++;
        campaigns[count]= Campaign({
        creator: msg.sender,
        goalTarget: _goalTarget,
        pledge:0
        startTime:_startTime
        endTime: _endTime
        claimed: false
        })
    }

    function cancel(uint _id) external {
        Campaign memory campaign = campaigns[_id];
        require(block.timestamp < campaign.startTime, "already started");
        require(msg.sender == campaign.creator, "you are not the creator");
        require(block.timestamp > endTime, "already ended");
        delete campaigns[_id];
        // emit
    }

    function pledged(uint _id, uint _amount) external {
        Campaign storage campaign = campaigns[_id];
        require(block.timestamp > campaign.startTime, "not yet started");
        require(block.timestamp <= endTime, "already ended");
        campaign.pledge += _amount;
        pledgeAmount[_id][msg.sender] += _amount;
        payable(msg.sender).transfer(campaign.creator, _amount)
        // emit 
    }

    function unpledged(uint _id, uint _amount) external {
        Campaign storage campaign = campaigns[_id];
        require(block.timestamp <= endTime, "already ended");
        campaign.pledge -= _amount;
        pledgeAmount[_id][msg.sender] -= _amount;
       payable(campaign.creator).transfer(msg.sender, _amount)
        // emit 
    }

    function claimedCampaign(unit _id) external{
         Campaign storage campaign = campaigns[_id];
         require(msg.sender == campaign.creator, "you are not the creator");
        require(block.timestamp > campaign.endTime, "not yet ended");
        require(campaign.pledge >= campaign.goalTarget, "target not reach");
        require(!campaign.claimed, "already claimed");

        campaign.claimed = true;
        // pledgeAmount
        campaign.pledge.transfer((msg.sender).balance);


        
    }

}