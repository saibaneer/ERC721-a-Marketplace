// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./AdminContract.sol";


contract Timer {

    uint public endAt;
    bool public started;
    bool public ended;

    event Start();
    event End();

    
    uint public tokenId;
    uint public bidTimeInHours;
    uint public startingPrice;

    address[] bidders; //key
    address nftAddress;
    AdminConsole admin;
    mapping(address => uint) public biddersToBid;
    
    uint public maximumBid;
    address public maximumBidder;

    constructor(address _nftAddress, uint _tokenId, uint _bidTimeInHours, uint _startingPrice, AdminConsole _admin) {
        nftAddress = _nftAddress;
        tokenId = _tokenId;
        bidTimeInHours = _bidTimeInHours; 
        startingPrice = _startingPrice;  
        admin = AdminConsole(_admin);    
    }

    //============TIMER FUNCTIONS======================
    // start timer
    function startTimer() public {
        started = true;
        uint bidTime = bidTimeInHours * 1 hours;
        endAt = block.timestamp + bidTime;
        emit Start();

    }    
    

    

    //============BID FUNCTIONS======================
    function bid(address account) payable public {
        require(admin.isAdmin(msg.sender) == true, "You do not have permission to access this contract!");
        require(_bidderExists(account) == false, "You already have an existing bid, update your bid instead!");
        require(msg.value > startingPrice && msg.value > maximumBid, "Your bid is not high enough");
        require(block.timestamp < endAt, "Bid already ended!");
        if(_endgameFlag() == true){
            endAt += 60;
        }
        
        bidders.push(account);   
        biddersToBid[account] = msg.value;

        maximumBid = biddersToBid[account];
        maximumBidder = account;
    }

    function updateBid(address account) payable public {
        require(admin.isAdmin(msg.sender) == true, "You do not have permission to access this contract!");
        require(_bidderExists(account) == true, "You have no previous bid!!");
        require(biddersToBid[account] > 0, "You have no previous bid!");
        require(msg.value + biddersToBid[account] > biddersToBid[account], "New bid must exceed previous Bid!");
        require(msg.value + biddersToBid[account] > maximumBid, "New Bid must exceed maximum bid!");
        require(block.timestamp < endAt, "Bid already ended!");
        if(_endgameFlag() == true){
            endAt += 60;
        }
        
        
        biddersToBid[account] += msg.value;
        maximumBid = biddersToBid[account];
        maximumBidder = account;
    }
    
    function withdrawBid(address account) public {
        require(admin.isAdmin(msg.sender) == true, "You do not have permission to access this contract!");
        require(biddersToBid[account] > 0, "You have no previous bid!");
        
        uint amount;
        for(uint i = 0; i < bidders.length; i++){            
            if(bidders[i] == account){
                amount = biddersToBid[bidders[i]];
                biddersToBid[bidders[i]] = 0;
                bidders[i] = bidders[bidders.length - 1];
                bidders.pop();
            }
        }

        

        (bool success, ) = payable(account).call{value:amount}("");
        require(success, "Failed to send Funds");

        biddersToBid[account] = 0;

        _maxBidCalcInternal();

    }

    //close contract
    function claimNFT() public {
        require(admin.isAdmin(msg.sender) == true, "Timer: You do not have permission to access this contract!");
        require(block.timestamp > endAt, "Timer: The Auction is not over!");
        ended = true;
        
        emit End();

    }

    //============GETTER FUNCTIONS======================
    function confirmBid(address account) public view returns(uint) {
        return biddersToBid[account];
    }   

    
    function maxBidder() public view returns(address) {
        (address highestBidder, ) = _maxBidCalc();
        return highestBidder;
    }

    function maxBid() public view returns(uint) {
        (, uint highestBid ) = _maxBidCalc();
        return highestBid;
    }

    

    //============HELPER FUNCTIONS======================

    function _maxBidCalcInternal() private {
        uint highestBid;
        address highestBidder;

        for(uint i = 0; i < bidders.length; i++){
            
            if(biddersToBid[bidders[i]] >= maximumBid){
                highestBid = biddersToBid[bidders[i]];
                highestBidder = bidders[i];
            }
        }
        maximumBid = highestBid;
        maximumBidder = highestBidder;        
    }

    function _maxBidCalc() public view returns(address highestBidder, uint highestBid) {
        
        for(uint i = 0; i < bidders.length; i++){            
            if(biddersToBid[bidders[i]] >= maximumBid){
                highestBid = biddersToBid[bidders[i]];
                highestBidder = bidders[i];
            }
        }
        
    }

    function _bidderExists(address account) private view returns(bool) {
        for(uint i = 0; i < bidders.length; i++){
            if(account == bidders[i]) {
                return true;
            }
        }
        return false;
    }

    function _endgameFlag() private view returns(bool) {
        uint endGame = endAt - 60;
        if(block.timestamp < endAt && block.timestamp >= endGame) {
            return true;
        }
        return false;
    }

    


}