// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "./IERC20.sol";

contract Market {

    struct Listing{
        address seller;
        bool sold;
        address token;
        uint price;
        uint tokenId;
    }

    mapping(uint=>Listing) public listings;
    uint listingId;

   function sellListing(address _token, uint _price, uint _tokenid)external{
    // IERC20(_token).transferFrom(msg.sender, address(this), _tokenid );
    Listing  memory listing = Listing(msg.sender, false , _token, _price, _tokenid);
     listingId ++;
     listings[listingId] = listing;
   }

   function buyListing(uint _id) external {
    Listing storage listing = listings[_id];
    require(listing.sold == false, "Listing alreading sold out");
    require(msg.sender != listing.seller, "Listing alreading sold out");
    listing.sold = true;
    IERC20(listing.token).transferFrom(address(this), msg.sender, listing.tokenId );
    payable(listing.seller).transfer(listing.price);

   }
   function cancelListing(uint _id) external {
    Listing storage listing = listings[_id];
    require(listing.sold == false, "Listing alreading sold out");
    require(msg.sender == listing.seller, "only owner can cancel out listing");
    listing.sold = true;
    IERC20(listing.token).transferFrom(address(this), msg.sender, listing.tokenId );

   }


}