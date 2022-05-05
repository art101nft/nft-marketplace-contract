// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract Marketplace is Ownable {
    using SafeMath for uint256;

    struct Offer {
        bool isForSale;
        uint tokenIndex;
        address seller;
        uint minValue;          // in ether
        address onlySellTo;     // specify to sell only to a specific person
    }

    struct Bid {
        bool hasBid;
        uint tokenIndex;
        address bidder;
        uint value;
    }

    // Track bids/offers
    mapping (uint => Offer) public tokenOffers;
    mapping (uint => Bid) public tokenBids;
    mapping (address => uint) public pendingWithdrawals;

    event Assign(address indexed to, uint256 tokenIndex);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event TokenTransfer(address indexed from, address indexed to, uint256 tokenIndex);
    event TokenOffered(uint indexed tokenIndex, uint minValue, address indexed toAddress);
    event TokenBidEntered(uint indexed tokenIndex, uint value, address indexed fromAddress);
    event TokenBidWithdrawn(uint indexed tokenIndex, uint value, address indexed fromAddress);
    event TokenBought(uint indexed tokenIndex, uint value, address indexed fromAddress, address indexed toAddress);
    event TokenNoLongerForSale(uint indexed tokenIndex);

    IERC721 public MARKET_CONTRACT;

    constructor(address contractAddress) {
        setMarketContract(contractAddress);
    }

    // Modifiers

    modifier onlyIfSeller(uint256 tokenIndex) {
        require(msg.sender == MARKET_CONTRACT.ownerOf(tokenIndex), "You must own the token.");
        _;
    }

    modifier onlyIfBuyer(uint256 tokenIndex) {
      address owner = MARKET_CONTRACT.ownerOf(tokenIndex)
      require(0x0 != owner, "Token must have an owner to enter bid.");
      require(msg.sender != owner, "Token owner cannot enter bid to self.");
        _;
    }

    // Administrative

    function setMarketContract(address _a) public onlyOwner {
        MARKET_CONTRACT = IERC721Enumerable(_a);
    }

    // Selling / offering

    function tokenNoLongerForSale(uint tokenIndex) public onlyIfSeller(tokenIndex) {
        tokenOffers[tokenIndex] = Offer(false, tokenIndex, msg.sender, 0, 0x0);
        emit TokenNoLongerForSale(tokenIndex);
    }

    function offerTokenForSale(uint tokenIndex, uint minSalePriceInWei) external onlyIfSeller(tokenIndex) {
        tokenOffers[tokenIndex] = Offer(true, tokenIndex, msg.sender, minSalePriceInWei, 0x0);
        emit TokenOffered(tokenIndex, minSalePriceInWei, 0x0);
    }

    function offerTokenForSaleToAddress(uint tokenIndex, uint minSalePriceInWei, address toAddress) external onlyIfSeller(tokenIndex) {
        tokenOffers[tokenIndex] = Offer(true, tokenIndex, msg.sender, minSalePriceInWei, toAddress);
        emit TokenOffered(tokenIndex, minSalePriceInWei, toAddress);
    }

    // Buying / bidding

    function enterBidForToken(uint tokenIndex) external payable onlyIfBuyer(tokenIndex) {
        require(msg.value > 0, "Must bid some amount of Ether.");
        Bid existing = tokenBids[tokenIndex];
        require(msg.value > existing.value, "Must bid higher than current bid.");
        // Refund the failing bid
        pendingWithdrawals[existing.bidder] += existing.value;
        tokenBids[tokenIndex] = Bid(true, tokenIndex, msg.sender, msg.value);
        emit TokenBidEntered(tokenIndex, msg.value, msg.sender);
    }

    function withdrawBidForToken(uint tokenIndex) external payable onlyIfBuyer(tokenIndex) {
        Bid bid = tokenBids[tokenIndex];
        require(msg.sender == bid.bidder, "Only original bidder can withdraw this bid.");
        emit TokenBidWithdrawn(tokenIndex, bid.value, msg.sender);
        uint amount = bid.value;
        tokenBids[tokenIndex] = Bid(false, tokenIndex, 0x0, 0);
        // Refund the bid money
        msg.sender.transfer(amount);
    }

    function acceptOfferForToken(uint tokenIndex) external payable onlyIfBuyer(tokenIndex) {
        Offer offer = tokenOffers[tokenIndex];
        require(offer.isForSale, "Token must be for sale by owner.");
        if (offer.onlySellTo != 0x0) {
            require(msg.sender == offer.onlySellTo, "Offer applies to other address.");
        }
        require(msg.value >= offer.minValue, "Not enough Ether sent.");
        require(offer.seller == MARKET_CONTRACT.ownerOf(tokenIndex), "Seller is no longer the owner, cannot accept offer.");

        address seller = offer.seller;

        emit Transfer(seller, msg.sender, 1);
        // MARKET_CONTRACT.safeTransferFrom

        tokenNoLongerForSale(tokenIndex);
        pendingWithdrawals[seller] += msg.value;
        emit TokenBought(tokenIndex, msg.value, seller, msg.sender);

        // Check for the case where there is a bid from the new owner and refund it.
        // Any other bid can stay in place.
        Bid bid = tokenBids[tokenIndex];
        if (bid.bidder == msg.sender) {
            // Kill bid and refund value
            pendingWithdrawals[msg.sender] += bid.value;
            tokenBids[tokenIndex] = Bid(false, tokenIndex, 0x0, 0);
        }
    }

    function acceptBidForToken(uint tokenIndex, uint minPrice) external payable onlyIfSeller(tokenIndex) {
        Bid bid = tokenBids[tokenIndex];
        address seller = msg.sender;
        require(bid.value => 0, "Bid must be greater than 0.");
        require(bid.value >= minPrice, "Bid must be greater than minimum price.");

        emit Transfer(seller, bid.bidder, 1);
        // MARKET_CONTRACT.safeTransferFrom

        tokenOffers[tokenIndex] = Offer(false, tokenIndex, bid.bidder, 0, 0x0);
        uint amount = bid.value;
        // Take cut
        tokenBids[tokenIndex] = Bid(false, tokenIndex, 0x0, 0);
        pendingWithdrawals[seller] += amount;
        emit TokenBought(tokenIndex, bid.value, seller, bid.bidder);
    }

    function withdraw() {
        uint amount = pendingWithdrawals[msg.sender];
        // Remember to zero the pending refund before
        // sending to prevent re-entrancy attacks
        pendingWithdrawals[msg.sender] = 0;
        msg.sender.transfer(amount);
    }

}
