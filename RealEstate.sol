// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


contract RealEstate{

    event BuyProperty(address buyer, uint value);

    struct Property {

    
        uint price;
        address owner;
        bool forsale;
        string name;
        string description;
        string location;
    }

    mapping(uint=>Property) public properties;
    uint[] public propertyId;
 function listingProperty(uint _propertyId, string memory _name, uint _price, string memory _description, string memory _location) external {
      Property memory newproperty = Property({
        price: _price,
        owner: msg.sender,
        name: _name,
        forsale: true, 
        description: _description,
        location: _location
      });
      properties[_propertyId] = newproperty;
      propertyId.push(_propertyId);
    }

      function buyProperty(uint _propertyId) external payable  {
       Property storage property = properties[_propertyId];
       require(property.forsale, "not available for sale");
       require(msg.value == property.price, "incorrect amount, check the price");
       property.forsale = false;

       payable(msg.sender).transfer(property.price);
       property.owner = msg.sender;

       emit BuyProperty(msg.sender, property.price) ;   

      }




}