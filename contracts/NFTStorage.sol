
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./AdminContract.sol";
import "./TimerContract.sol";
import "./Minter.sol";
import "./BatchMinter.sol";

contract MyNFTStorage {

    Minter minter;
    AdminConsole admin;
    

    event ListedForBid(address indexed nftAddress, uint indexed tokenId, address owner, uint price, address indexed timerContract);
    event ListedForSale(address indexed nftAddress, uint indexed tokenId, address owner, uint price);
    error NotApprovedForMarketplace();

    constructor(address _minterAddress, address _admin){
        minter = Minter(_minterAddress);
        admin = AdminConsole(_admin);
    }
    
    

    enum ListingStatus {
        ForSale,
        ForBid,
        Sold,
        Cancelled
    }

    struct Token {
        
        uint tokenId;
        uint tokenPrice;
        address owner;
        address nftAddress;
        ListingStatus status;
    }

    struct TokenItem {
        address nftAddress;
        uint[] tokenId;
    }

    //================LISTING MAPPINGS=========================
    //every NFT has a token object
    mapping(address => mapping(uint => Token)) nftToTokenObject;
    mapping(address => mapping(address => uint))  userToNftToNftCount;

    //keep track of each user's NFT user => NFT Address(es), one user to many NFTs
    mapping(address => mapping(address => TokenItem)) public userToNftToTokenItem;
    mapping(address => mapping(uint => address)) nftToTokenIdToTimerContract; //listing to Bid timer


    function _createListingForBid(address _nft, uint tokenId, uint tokenPrice, address tokenOwner, uint bidTimeInHours) public { //please ensure that this remains internal
        require(admin.isAdmin(msg.sender) == true, "You do not have permission to access this contract!");
        IERC721 nft = IERC721(_nft);
        // if (nft.getApproved(tokenId) != address(this)) {
        //     revert NotApprovedForMarketplace();
        // }
        require(nft.ownerOf(tokenId) == tokenOwner, "NFTStorage: You do not have permission to list this token"); //check that the lister owns the token
        Token memory token = nftToTokenObject[_nft][tokenId];
        token = Token(tokenId, tokenPrice, payable(tokenOwner), _nft, ListingStatus.ForBid);

        
        
        uint feePercent = admin.getFeePercent();
        token.tokenPrice = tokenPrice;
        token.tokenPrice = token.tokenPrice*(10000 + feePercent)/10000;
        nftToTokenObject[_nft][tokenId] = token;

        if(userToNftToNftCount[tokenOwner][_nft] == 0){
            userToNftToTokenItem[tokenOwner][_nft].nftAddress = _nft; //adds the nft address to the token item struct
            userToNftToTokenItem[tokenOwner][_nft].tokenId.push(tokenId); 
        } else {
            userToNftToTokenItem[tokenOwner][_nft].tokenId.push(tokenId);
        }        

        Timer timer = new Timer(_nft, tokenId, bidTimeInHours, token.tokenPrice, admin);
        timer.startTimer();
        nftToTokenIdToTimerContract[_nft][tokenId] = address(timer); //Store timer contract
        userToNftToNftCount[tokenOwner][_nft] += 1;
        nft.transferFrom(tokenOwner, address(this), tokenId);
        emit ListedForBid(_nft, tokenId, tokenOwner, token.tokenPrice, address(timer));
    }

    function _createListingForSale(address _nft, uint tokenId, uint tokenPrice, address tokenOwner) public { //please ensure that this remains internal
        require(admin.isAdmin(msg.sender) == true, "NFTStorage: You do not have permission to access this contract!");
        IERC721 nft = IERC721(_nft);
        // if (nft.getApproved(tokenId) != address(this)) {
        //     revert NotApprovedForMarketplace();
        // }
        require(nft.ownerOf(tokenId) == tokenOwner, "You do not have permission to list this token"); //check that the lister owns the token
        Token memory token = nftToTokenObject[_nft][tokenId];
        token = Token(tokenId, tokenPrice, payable(tokenOwner), _nft, ListingStatus.ForSale);
        uint feePercent = admin.getFeePercent();
        token.tokenPrice = tokenPrice;
        token.tokenPrice = token.tokenPrice*(10000 + feePercent)/10000;
        nftToTokenObject[_nft][tokenId] = token;

        if(userToNftToNftCount[tokenOwner][_nft] == 0){
            userToNftToTokenItem[tokenOwner][_nft].nftAddress = _nft; //adds the nft address to the token item struct
            userToNftToTokenItem[tokenOwner][_nft].tokenId.push(tokenId); 
            
        } else {
            userToNftToTokenItem[tokenOwner][_nft].tokenId.push(tokenId);
        }      
        userToNftToNftCount[tokenOwner][_nft] += 1;
        nft.transferFrom(tokenOwner, address(this), tokenId);    
        emit ListedForSale(_nft, tokenId, tokenOwner, token.tokenPrice);
    }

    function _claimToken(uint tokenId, address nftAddress, address buyer) public {
        Token storage myToken = nftToTokenObject[nftAddress][tokenId];
        require(admin.isAdmin(msg.sender) == true, "You do not have permission to access this contract!");
        if(myToken.status == ListingStatus.ForBid) {
            //change owner based on condition from Timer
            Timer auction = Timer(nftToTokenIdToTimerContract[nftAddress][tokenId]);
            auction.claimNFT();
            //If owner is winner && bid time is over
        } 
        address prevOwner = myToken.owner;  
        //modify userToNftToNftCount
        userToNftToNftCount[prevOwner][nftAddress] -= 1; //(check that this cannot be zero)
        _removeToken(tokenId, nftAddress, prevOwner); //modify userToNftToTokenItem
        myToken.owner = buyer;
        userToNftToNftCount[buyer][nftAddress] += 1; //(check that this cannot be zero)
        userToNftToTokenItem[buyer][nftAddress].tokenId.push(tokenId);
        userToNftToTokenItem[buyer][nftAddress].nftAddress = nftAddress;
        myToken.status = ListingStatus.Sold;           
    }

    function _withdrawNFT(uint tokenId, address nftAddress, address tokenOwner) public {
        require(admin.isAdmin(msg.sender) == true, "You do not have permission to access this contract!");
        //validate that he/she has the quantity
        Token storage myToken = nftToTokenObject[nftAddress][tokenId];
        require(myToken.owner == tokenOwner, "You do not own this token!");
        myToken.owner = address(0);
        myToken.tokenPrice = 0;

        userToNftToNftCount[tokenOwner][nftAddress] -= 1; //(check that this cannot be zero)
        _removeToken(tokenId, nftAddress, tokenOwner); //modify userToNftToTokenItem
        IERC721 nft = IERC721(nftAddress);
        nft.transferFrom(address(this), tokenOwner, tokenId); 
    }

    function _relistTokenForSale(uint tokenId, address nftAddress, uint price, address tokenOwner) public {
        require(admin.isAdmin(msg.sender) == true, "You do not have permission to access this contract!");
        Token storage myToken = nftToTokenObject[nftAddress][tokenId];
        require(tokenOwner == myToken.owner, "You do not own this token!");
        require(myToken.status == ListingStatus.Sold, "You cannot relist this token!");        

        myToken.tokenPrice = price;
        myToken.status = ListingStatus.ForSale; 
             
        
        uint feePercent = admin.getFeePercent();
        myToken.tokenPrice = price;
        myToken.tokenPrice = myToken.tokenPrice*(10000 + feePercent)/10000;
    }

    function _relistTokenForBid(uint tokenId, address nftAddress, uint price, address tokenOwner, uint bidTimeInHours) public {
        require(admin.isAdmin(msg.sender) == true, "You do not have permission to access this contract!");
        Token storage myToken = nftToTokenObject[nftAddress][tokenId];
        require(tokenOwner == myToken.owner, "You do not own this token!");
        require(myToken.status == ListingStatus.Sold, "You cannot relist this token!");        

        myToken.tokenPrice = price;
        myToken.status = ListingStatus.ForBid;  
        uint feePercent = admin.getFeePercent();
        myToken.tokenPrice = price;
        myToken.tokenPrice = myToken.tokenPrice*(10000 + feePercent)/10000; 

        Timer timer = new Timer(nftAddress, tokenId, bidTimeInHours, myToken.tokenPrice, admin);
        timer.startTimer();
        nftToTokenIdToTimerContract[nftAddress][tokenId] = address(timer); //Store timer contract
    }

    function _updateListingPrice(uint tokenId, address nftAddress, uint price, address tokenOwner) public {
        require(admin.isAdmin(msg.sender) == true, "You do not have permission to access this contract!");
        Token storage myToken = nftToTokenObject[nftAddress][tokenId];
        require(tokenOwner == myToken.owner, "You do not own this token!");
        require(myToken.status == ListingStatus.ForSale, "You cannot perform this action"); 
        myToken.tokenPrice = price;
    }

    
    function getTokenPrice(uint tokenId, address nftAddress) public view returns(uint) {
        return nftToTokenObject[nftAddress][tokenId].tokenPrice;
    }

    function getTokenObject(uint tokenId, address nftAddress) public view returns(Token memory) {
        return nftToTokenObject[nftAddress][tokenId];
    }

    function getTokenOwner(uint tokenId, address nftAddress) public view returns(address) {
        return nftToTokenObject[nftAddress][tokenId].owner;
    }  

    function getTokenStatus(uint tokenId, address nftAddress) public view returns(ListingStatus) {
        return nftToTokenObject[nftAddress][tokenId].status;
    }  

    function isListedForSale(uint tokenId, address nftAddress) public view returns(bool) {
        //token exists if at least 1 unit exists
        Token storage myToken = nftToTokenObject[nftAddress][tokenId];
        if(myToken.status == ListingStatus.ForSale){
            return true;
        } else {
            return false;
        }
    }

    function isListedForBid(uint tokenId, address nftAddress) public view returns(bool) {
        //token exists if at least 1 unit exists
        Token storage myToken = nftToTokenObject[nftAddress][tokenId];
        if(myToken.status == ListingStatus.ForBid){
            return true;
        } else {
            return false;
        }
    }

    function _removeToken(uint tokenId, address nftAddress, address tokenOwner) private {
        TokenItem storage userTokenItem = userToNftToTokenItem[tokenOwner][nftAddress];
        uint[] storage tokenArray = userTokenItem.tokenId;
        for(uint i = 0; i < tokenArray.length; i++){
            if(tokenId == tokenArray[i]){
                tokenArray[i] = tokenArray[tokenArray.length - 1];
                tokenArray.pop();
            }
        }
    }

    function fetchBidContract(uint tokenId, address nftAddress) public view returns(address) {
        return nftToTokenIdToTimerContract[nftAddress][tokenId];
    }
}