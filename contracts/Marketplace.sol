// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract Marketplace is Ownable {
    using SafeMath for uint256;

    struct Offer {
        bool isForSale;
        uint256 tokenIndex;
        address seller;
        uint256 minValue;          // in ether
        address onlySellTo;     // specify to sell only to a specific person
    }

    struct Bid {
        bool hasBid;
        uint256 tokenIndex;
        address bidder;
        uint256 value;
    }

    struct Collection {
        bool status;
        uint256 royaltyPercent;
    }

    // Nested mappings for each collection's offers, bids, and state
    mapping (address => mapping(uint256 => Offer)) public tokenOffers;
    mapping (address => mapping(uint256 => Bid)) public tokenBids;
    mapping (address => Collection) public collectionState;
    mapping (address => uint256) public pendingWithdrawals;

    // Log events
    event Transfer(address indexed collectionAddress, address indexed from, address indexed to, uint256 value);
    event TokenTransfer(address indexed collectionAddress, address indexed from, address indexed to, uint256 tokenIndex);
    event TokenOffered(address indexed collectionAddress, uint256 indexed tokenIndex, uint256 minValue, address indexed toAddress);
    event TokenBidEntered(address indexed collectionAddress, uint256 indexed tokenIndex, uint256 value, address indexed fromAddress);
    event TokenBidWithdrawn(address indexed collectionAddress, uint256 indexed tokenIndex, uint256 value, address indexed fromAddress);
    event TokenBought(address indexed collectionAddress, uint256 indexed tokenIndex, uint256 value, address fromAddress, address toAddress);
    event TokenNoLongerForSale(address indexed collectionAddress, uint256 indexed tokenIndex);

    constructor() {
        // do stuff...
    }

    // Modifiers

    modifier onlyIfSeller(address contractAddress, uint256 tokenIndex) {
        require(msg.sender == IERC721(contractAddress).ownerOf(tokenIndex), "You must own the token.");
        _;
    }

    modifier onlyIfBuyer(address contractAddress, uint256 tokenIndex) {
      address owner = IERC721(contractAddress).ownerOf(tokenIndex);
      require(msg.sender != owner, "Token owner cannot enter bid to self.");
        _;
    }

    // Administrative

    function addMarketContract(address contractAddress, uint256 royaltyPercent) public onlyOwner {
        require(royaltyPercent <= 100, "Cannot exceed 100%");
        collectionState[contractAddress] = Collection(true, royaltyPercent);
    }

    // Selling / offering

    function tokenNoLongerForSale(address contractAddress, uint256 tokenIndex) public onlyIfSeller(contractAddress, tokenIndex) {
        tokenOffers[contractAddress][tokenIndex] = Offer(false, tokenIndex, msg.sender, 0, address(0x0));
        emit TokenNoLongerForSale(contractAddress, tokenIndex);
    }

    function offerTokenForSale(address contractAddress, uint256 tokenIndex, uint256 minSalePriceInWei) external onlyIfSeller(contractAddress, tokenIndex) {
        tokenOffers[contractAddress][tokenIndex] = Offer(true, tokenIndex, msg.sender, minSalePriceInWei, address(0x0));
        emit TokenOffered(contractAddress, tokenIndex, minSalePriceInWei, address(0x0));
    }

    function offerTokenForSaleToAddress(address contractAddress, uint256 tokenIndex, uint256 minSalePriceInWei, address toAddress) external onlyIfSeller(contractAddress, tokenIndex) {
        tokenOffers[contractAddress][tokenIndex] = Offer(true, tokenIndex, msg.sender, minSalePriceInWei, toAddress);
        emit TokenOffered(contractAddress, tokenIndex, minSalePriceInWei, toAddress);
    }

    // Buying / bidding

    function enterBidForToken(address contractAddress, uint256 tokenIndex) external payable onlyIfBuyer(contractAddress, tokenIndex) {
        require(msg.value > 0, "Must bid some amount of Ether.");
        Bid memory existing = tokenBids[contractAddress][tokenIndex];
        require(msg.value > existing.value, "Must bid higher than current bid.");
        // Refund the failing bid
        pendingWithdrawals[existing.bidder] += existing.value;
        tokenBids[contractAddress][tokenIndex] = Bid(true, tokenIndex, msg.sender, msg.value);
        emit TokenBidEntered(contractAddress, tokenIndex, msg.value, msg.sender);
    }

    function withdrawBidForToken(address contractAddress, uint256 tokenIndex) external payable onlyIfBuyer(contractAddress, tokenIndex) {
        Bid memory bid = tokenBids[contractAddress][tokenIndex];
        require(msg.sender == bid.bidder, "Only original bidder can withdraw this bid.");
        emit TokenBidWithdrawn(contractAddress, tokenIndex, bid.value, msg.sender);
        uint256 amount = bid.value;
        tokenBids[contractAddress][tokenIndex] = Bid(false, tokenIndex, address(0x0), 0);
        // Refund the bid money
        payable(msg.sender).transfer(amount);
    }

    function acceptOfferForToken(address contractAddress, uint256 tokenIndex) external payable onlyIfBuyer(contractAddress, tokenIndex) {
        Offer memory offer = tokenOffers[contractAddress][tokenIndex];
        require(offer.isForSale, "Token must be for sale by owner.");
        if (offer.onlySellTo != address(0x0)) {
            require(msg.sender == offer.onlySellTo, "Offer applies to other address.");
        }
        require(msg.value >= offer.minValue, "Not enough Ether sent.");
        require(offer.seller == IERC721(contractAddress).ownerOf(tokenIndex), "Seller is no longer the owner, cannot accept offer.");

        address seller = offer.seller;

        emit Transfer(contractAddress, seller, msg.sender, 1);
        // IERC721(contractAddress).safeTransferFrom

        tokenNoLongerForSale(contractAddress, tokenIndex);
        pendingWithdrawals[seller] += msg.value;
        emit TokenBought(contractAddress, tokenIndex, msg.value, seller, msg.sender);

        // Check for the case where there is a bid from the new owner and refund it.
        // Any other bid can stay in place.
        Bid memory bid = tokenBids[contractAddress][tokenIndex];
        if (bid.bidder == msg.sender) {
            // Kill bid and refund value
            pendingWithdrawals[msg.sender] += bid.value;
            tokenBids[contractAddress][tokenIndex] = Bid(false, tokenIndex, address(0x0), 0);
        }
    }

    function acceptBidForToken(address contractAddress, uint256 tokenIndex, uint256 minPrice) external payable onlyIfSeller(contractAddress, tokenIndex) {
        Bid memory bid = tokenBids[contractAddress][tokenIndex];
        address seller = msg.sender;
        require(bid.value > 0, "Bid must be greater than 0.");
        require(bid.value >= minPrice, "Bid must be greater than minimum price.");

        emit Transfer(contractAddress, seller, bid.bidder, 1);
        // IERC721(contractAddress).safeTransferFrom

        tokenOffers[contractAddress][tokenIndex] = Offer(false, tokenIndex, bid.bidder, 0, address(0x0));
        uint256 amount = bid.value;
        // Take cut
        tokenBids[contractAddress][tokenIndex] = Bid(false, tokenIndex, address(0x0), 0);
        pendingWithdrawals[seller] += amount;
        emit TokenBought(contractAddress, tokenIndex, bid.value, seller, bid.bidder);
    }

    function withdraw() external {
        uint256 amount = pendingWithdrawals[msg.sender];
        // Remember to zero the pending refund before
        // sending to prevent re-entrancy attacks
        pendingWithdrawals[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

}
