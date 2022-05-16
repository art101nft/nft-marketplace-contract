// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract SampleProject1155 is ERC1155, Ownable {
    constructor() ERC1155("") {}

    function mint(uint256 tokenId, uint256 amount) external {
        for(uint256 i = 0; i < amount; i++) {
            _mint(msg.sender, tokenId, 1, "");
        }
    }

}
