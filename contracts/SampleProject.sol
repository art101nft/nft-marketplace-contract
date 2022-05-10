// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract SampleProject is ERC721A, Ownable {
    constructor() ERC721A("Sample Project", "SP") {}

    function mint(uint256 amount) external {
      _safeMint(msg.sender, amount);
    }
}
