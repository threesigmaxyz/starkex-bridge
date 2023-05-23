//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC721 } from "@openzeppelin/token/ERC721/ERC721.sol";

contract MockERC721 is ERC721 {
    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) { }

    function safeMint(address recipient_, uint256 tokenId_) external {
        _safeMint(recipient_, tokenId_);
    }

    function burn(uint256 tokenId_) external {
        _burn(tokenId_);
    }
}
