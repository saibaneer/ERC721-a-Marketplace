//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

contract BatchMinter is ERC721A, ERC2981 {

    uint96 public royaltyFee;
    uint quantity;
    address immutable public i_owner;

    constructor(string memory _name, string memory _symbol, uint96 _fee, uint _quantity, address owner) ERC721A(_name, _symbol) {
        royaltyFee = _fee;
        quantity = _quantity;
        i_owner = owner;

    }

    function mint(address operator, address account) external {
        // _safeMint's second argument now takes in a quantity, not a tokenId.
        _safeMint(account, quantity); 
        setApprovalForAll(operator, true);       
        _setDefaultRoyalty(msg.sender, royaltyFee);
    }

    

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721A)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721A, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    
}