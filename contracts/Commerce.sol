// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./NFTStorage.sol";
import "./AdminContract.sol";
import "./TimerContract.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "hardhat/console.sol";

contract Commerce {

    event Buy(uint indexed tokenId, address nftAddress, uint indexed pricePaid, address buyer);
    event Bid(uint indexed tokenId, address nftAddress, uint indexed pricePaid, address bidder);
    event AcceptedOffer(uint indexed tokenId, address indexed seller, address buyer, uint quantity, uint indexed index);
    event WithdrewOffer(uint indexed tokenId, address tokenOwner, address indexed caller, uint amount, uint index);
    event UpdatedOffer(uint indexed tokenId, address tokenOwner, address indexed caller, uint amount, uint index);
    event WithdrewNFT(uint tokenId, address owner);
    event WithdrewFunds(address indexed caller, uint indexed amount);
    event WithdrewMarketFunds(address indexed caller, uint indexed amount);


    MyNFTStorage vault;
    AdminConsole admin;
    address owner;

    constructor(address _vault, address _admin){
        vault = MyNFTStorage(_vault);
        admin = AdminConsole(_admin);
        owner = msg.sender;
    }

    

    // mapping(uint => mapping(address => uint)) public deposits;
    mapping(address => uint) public deposits;
    

    function buy(uint tokenId, address nftAddress) payable public {     
        
        uint price = vault.getTokenPrice(tokenId, nftAddress);  
        require(msg.value >= price, "Commerce: Insufficient amount for the chosen quantity!");
        require(vault.isListedForSale(tokenId, nftAddress) == true, "Commerce: You cannot buy this token!");         
        
        
        address seller = vault.getTokenOwner(tokenId, nftAddress);
        uint amount = msg.value;

        uint feePercent = admin.getFeePercent();
        address feeAccount = admin.getFeeAccount();

        uint dueMarketplace = amount * feePercent/10000;
        uint dueSeller = amount - dueMarketplace;

        IERC2981 token = IERC2981(nftAddress);

        (address creator, uint dueCreator) = token.royaltyInfo(tokenId, dueSeller);
        // console.log("Token creator is: ", creator);
        // console.log("Funds due creator is: ", dueCreator);

        dueSeller = dueSeller - dueCreator;

        deposits[seller] += dueSeller;
        deposits[creator] += dueCreator;
        deposits[feeAccount] += dueMarketplace;
        
        vault._claimToken(tokenId, nftAddress, msg.sender);
        
        //add event with array id;
        emit Buy(tokenId, nftAddress, amount, msg.sender);
        amount = 0;
    }

    function bid(uint tokenId, address nftAddress) payable external {
         require(vault.isListedForBid(tokenId, nftAddress) == true, "You cannot bid for this token!"); 
        //fetch bid contract.
        address timer = vault.fetchBidContract(tokenId, nftAddress);
        require(timer != address(0), "You cannot bid on this item!");

        //push funds
        uint amount = msg.value;
        Timer auction = Timer(timer);
        auction.bid{value: amount}(msg.sender);
        emit Bid(tokenId, nftAddress, amount, msg.sender);
    }

    function updateBid(uint tokenId, address nftAddress) payable external {
        //fetch bid contract.
        address timer = vault.fetchBidContract(tokenId, nftAddress);
        require(timer != address(0), "You cannot bid on this item!");

        //push funds
        Timer auction = Timer(timer);
        auction.updateBid{value: msg.value}(msg.sender);
    }

    function withdrawBid(uint tokenId, address nftAddress) external {
        //fetch bid contract.
        address timer = vault.fetchBidContract(tokenId, nftAddress);
        require(timer != address(0), "You cannot bid on this item!");

        //push funds
        Timer auction = Timer(timer);
        auction.withdrawBid(msg.sender);
    }

    function confirmBid(uint tokenId, address nftAddress) external view returns(address bidder, uint thisBid) {
        address timer = vault.fetchBidContract(tokenId, nftAddress);
        require(timer != address(0), "No bid exists for this item!");

        Timer auction = Timer(timer);
        thisBid = auction.confirmBid(msg.sender);
        bidder = msg.sender;
    }

    function claimItem(uint tokenId, address nftAddress) external {
        //fetch bid contract.
        address timer = vault.fetchBidContract(tokenId, nftAddress);
        require(timer != address(0), "Commerce: You cannot bid on this item!");

        //push funds
        Timer auction = Timer(timer);
        
        require(block.timestamp > auction.endAt(), "Commerce: Auction is still open, wait until close!");
        require(msg.sender == auction.maxBidder(), "Commerce: You are not the highest bidder");
        uint highestBid = auction.maxBid();

        address seller = vault.getTokenOwner(tokenId, nftAddress);
        

        uint feePercent = admin.getFeePercent();
        address feeAccount = admin.getFeeAccount();

        uint dueMarketplace = highestBid * feePercent/10000;
        uint dueSeller = highestBid - dueMarketplace;

        IERC2981 token = IERC2981(nftAddress);

        (address creator, uint dueCreator) = token.royaltyInfo(tokenId, dueSeller);

        dueSeller = dueSeller - dueCreator;

        deposits[seller] += dueSeller;
        deposits[creator] += dueCreator;
        deposits[feeAccount] += dueMarketplace;
        
        vault._claimToken(tokenId, nftAddress, msg.sender);
    }    

    

    function withdrawNFTs(uint tokenId, address nftAddress) external {
        vault._withdrawNFT(tokenId, nftAddress, msg.sender);

        emit WithdrewNFT(tokenId, msg.sender);
    }

    function withdrawFunds() payable public {
        require(deposits[msg.sender] > 0, "You have no funds in this contract!");
        uint amount = deposits[msg.sender];

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Failed to send Ether");

        deposits[msg.sender] = 0;

        emit WithdrewFunds(msg.sender, amount);
        amount = 0;
    }

    function withdrawMarketfunds() payable external {
        address feeAccount = admin.getFeeAccount();
        require(msg.sender == feeAccount, "You are not authorized!");
        uint amount = deposits[feeAccount];
        deposits[feeAccount] = 0;
        
        (bool success, ) = payable(feeAccount).call{value: (amount*99)/100}("");
        require(success, "Failed to send Ether");

        

        emit WithdrewMarketFunds(feeAccount, amount);
        
    }

    function getBalance() public view returns(uint) {
        return deposits[msg.sender];
    }

}