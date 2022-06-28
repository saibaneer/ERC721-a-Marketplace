// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

contract Minter is ERC721, ERC721Enumerable, ERC2981, ERC721URIStorage, Ownable {
 
    using Counters for Counters.Counter;
    event Minted(uint tokenId, address operator, address contractAddress);
    

    Counters.Counter private _tokenIdCounter;
    uint96 royaltyFee;

    constructor(string memory _name, string memory _symbol, uint96 _fee) ERC721(_name, _symbol) {
        royaltyFee = _fee;
    }

    // function _baseURI() internal pure override returns (string memory) {
    //     return "https://monion.api/{id}.json/";
    // }

    function safeMint(string memory uri, address operator) public  {
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();
        
        _safeMint(msg.sender, tokenId);
        setApprovalForAll(operator, true);
        _setTokenURI(tokenId, uri);
        _setDefaultRoyalty(msg.sender, royaltyFee);
        emit Minted(tokenId, operator, address(this));
    }

    

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC2981, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}