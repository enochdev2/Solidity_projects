// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EventContract{

    struct Event{
        address organiser;
        string name;
        uint price;
        uint date;
        uint totalTicket;
        uint remainingTikcet;
    }

    mapping(uint=>Event) public events;
    mapping(address=>mapping(uint=>uint)) public mainEvent;
    uint eventId;

    function createEvent( string calldata _name, uint _price, uint _date, uint _totalTicket)external {
     require(block.timestamp>_date,"no such event");
     require(_totalTicket>0,"ticket must be more than 0");
     events[eventId] = Event({
        organiser: msg.sender,
        name: _name,
        price: _price,
        date: _date,
        totalTicket: _totalTicket,
        remainingTikcet: _totalTicket
     });
     eventId++;
    }

   function buyTicket(uint id,uint quantity) external payable {
      require(events[id].date !=0,"no such event");
      require(events[id].date>block.timestamp, " event ended");
      Event storage _event=events[id];
      require(msg.value==(_event.price*quantity), "not enough ether");        
      require(_event.remainingTikcet>quantity, "not enough Ticket");  
      _event.remainingTikcet -= quantity;
      mainEvent[msg.sender][id]+=quantity;      
   }

    function transferTicket(uint id, uint quantity, address _to) external {
        require(events[id].date !=0, "event does not exist");
       require(events[id].date> block.timestamp, "event already past");
        require( mainEvent[msg.sender][id]>=quantity, "you do not have enought ticket");
         mainEvent[msg.sender][id] -= quantity;
          mainEvent[_to][id] += quantity; 
    }
}