// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract SampleProject1155 is ERC1155, Ownable {
    constructor() ERC1155("") {}

    function mintItem(uint256 amount) external {
        for(uint256 i = 0; i < amount; i++) {
            uint256 tokenId = ((block.number + i) % 3) + 1;
            _mint(msg.sender, tokenId, 1, "");
        }
    }

}
