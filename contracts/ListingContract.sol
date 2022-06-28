// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./NFTStorage.sol";
// import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "erc721a/contracts/interfaces/IERC721A.sol";
import "hardhat/console.sol";
import "./BatchMinter.sol";

contract Listing {

    event Minted(address nftAddress, address owner, uint quantity, uint fees);

    MyNFTStorage vault;

    constructor(address _storageAddress){
        vault = MyNFTStorage(_storageAddress);
    }

    function batchMinting(string memory _name, string memory _symbol, uint96 _fee, uint _quantity) external {
        BatchMinter batchMinter = new BatchMinter(_name, _symbol, _fee, _quantity, msg.sender);
        address nftAddress = address(batchMinter);
        address operator = address(vault);
        batchMinter.mint(operator, msg.sender);
        emit Minted(nftAddress, msg.sender, _quantity, _fee);
    }

    function mintFromOwnersNFT(address nftAddress, uint quantity) external {
        BatchMinter batchMinter = BatchMinter(nftAddress);
        require(batchMinter.i_owner() == msg.sender, "ListingContract: You cannot mint from this NFT");
        // address nftAddress = address(batchMinter);
        address operator = address(vault);
        batchMinter.mint(operator, msg.sender);
        emit Minted(nftAddress, msg.sender, quantity, batchMinter.royaltyFee());
    }

    function addListingForSale(address nftAddress, uint tokenId, uint tokenPrice) external  {
        //IERC721 _nft = IERC721(nftAddress);
        vault._createListingForSale(nftAddress, tokenId, tokenPrice, msg.sender);
    }

    function batchListingForSale(address nftAddress, uint[] memory _tokenIds, uint tokenPrice) external {
        uint[] memory tokenIds = _tokenIds;
        uint length = tokenIds.length;
        IERC721A batchNFT = IERC721A(nftAddress);
        for(uint i = 0; i < length; i++) {
            
            //you must be owner
            if(msg.sender != batchNFT.ownerOf(tokenIds[i])){
                console.log('...adding token %d', tokenIds[i]);
                revert("You can only add tokens you own!");
            }            
        }

        for(uint i = 0; i < length; i++) {
            vault._createListingForSale(nftAddress, tokenIds[i], tokenPrice, msg.sender);
        }
    }

    

    function batchListingForBid(address nftAddress, uint[] memory _tokenIds, uint tokenPrice, uint bidTimeInHours) public {
        uint[] memory tokenIds = _tokenIds;
        uint length = tokenIds.length;
        IERC721A batchNFT = IERC721A(nftAddress);
        for(uint i = 0; i < length; i++) {
            
            //you must be owner
            if(msg.sender != batchNFT.ownerOf(tokenIds[i])){
                console.log('...adding token %d', tokenIds[i]);
                revert("You can only add tokens you own!");
            }            
        }

        for(uint i = 0; i < length; i++) {
            vault._createListingForBid(nftAddress, tokenIds[i], tokenPrice, msg.sender, bidTimeInHours);
        }
    }

    function addListingForBid(address nftAddress, uint tokenId, uint tokenPrice, uint bidTimeInHours) external {
        //IERC721 _nft = IERC721(nftAddress);
        vault._createListingForBid(nftAddress, tokenId, tokenPrice, msg.sender, bidTimeInHours);
    }

    function updateListingPrice(address nftAddress, uint tokenId, uint tokenPrice) external {
        vault._updateListingPrice(tokenId, nftAddress, tokenPrice, msg.sender);
    }


    function relistToken_forBid(address nftAddress, uint tokenId, uint price, uint bidTimeInHours) public {
        vault._relistTokenForBid(tokenId, nftAddress, price, msg.sender, bidTimeInHours);
    }

    function relistToken_forSale(address nftAddress, uint tokenId, uint price) public {
        vault._relistTokenForSale(tokenId, nftAddress, price, msg.sender);
    }

    function delistToken(address nftAddress, uint tokenId) public {
        vault._withdrawNFT(tokenId, nftAddress, msg.sender);
    }

    

}