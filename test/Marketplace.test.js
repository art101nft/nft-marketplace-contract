const Marketplace = artifacts.require("Marketplace");
const SampleProject = artifacts.require("SampleProject");
const { BN, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');


contract('Marketplace', function(accounts) {

  const nullAddress = '0x0000000000000000000000000000000000000000';

  function getPrice(amtEth) {
    return web3.utils.toWei(amtEth.toString())
  }

  beforeEach(async function () {
    this.mp = await Marketplace.new({from: accounts[0]});
    this.sample = await SampleProject.new({from: accounts[0]});
    await this.sample.mint(10, {from: accounts[0]});
  });

  // updateCollection

  it('confirms updateCollection requires contract ownership', async function () {
    await expectRevert(
      this.mp.updateCollection(this.sample.address, 1, "", {from: accounts[1]}),
      'You must own the contract.'
    );
    await expectEvent(
      await this.mp.updateCollection(this.sample.address, 5, "ipfs://ok", {from: accounts[0]}),
      'CollectionUpdated'
    );
  });

  it('confirms updateCollection updates each time', async function () {
    // add/update collection as owner
    await this.mp.updateCollection(this.sample.address, 1, "ipfs://mynewhash", {from: accounts[0]});
    // settings should match
    await expect(
      (await this.mp.collectionState(this.sample.address)).status
    ).to.equal(true);
    await expect(
      (await this.mp.collectionState(this.sample.address)).royaltyPercent
    ).to.be.bignumber.equal('1');
    await expect(
      (await this.mp.collectionState(this.sample.address)).metadataURL
    ).to.equal("ipfs://mynewhash");
    // Disable collection (zero it out)
    await this.mp.disableCollection(this.sample.address, {from: accounts[0]});
    // update collection again
    await this.mp.updateCollection(this.sample.address, 5, "ipfs://anothernewhash", {from: accounts[0]});
    await expect(
      (await this.mp.collectionState(this.sample.address)).status
    ).to.equal(true);
    await expect(
      (await this.mp.collectionState(this.sample.address)).royaltyPercent
    ).to.be.bignumber.equal('5');
    await expect(
      (await this.mp.collectionState(this.sample.address)).metadataURL
    ).to.equal("ipfs://anothernewhash");
    // update again
    await this.mp.updateCollection(this.sample.address, 8, "ipfs://round3", {from: accounts[0]});
    await expect(
      (await this.mp.collectionState(this.sample.address)).status
    ).to.equal(true);
    await expect(
      (await this.mp.collectionState(this.sample.address)).royaltyPercent
    ).to.be.bignumber.equal('8');
    await expect(
      (await this.mp.collectionState(this.sample.address)).metadataURL
    ).to.equal("ipfs://round3");
  });

  // disableCollection

  it('confirms disableCollection requires active contract', async function () {
    // try disableCollection when not enabled, should fail
    await expectRevert(
      this.mp.disableCollection(this.sample.address, {from: accounts[0]}),
      'Collection must be enabled on this contract by project owner.'
    );
  })

  it('confirms disableCollection requires contract ownership', async function () {
    // enable/update collection
    await this.mp.updateCollection(this.sample.address, 1, "ipfs://mynewhash", {from: accounts[0]});
    // try disableCollection as wrong owner, should fail
    await expectRevert(
      this.mp.disableCollection(this.sample.address, {from: accounts[1]}),
      'You must own the contract.'
    );
  });

  it('confirms disableCollection zeroes and disables collections', async function () {
    // update collection
    await this.mp.updateCollection(this.sample.address, 1, "ipfs://mynewhash", {from: accounts[0]});
    // try disableCollection as contract owner, should succeed
    await expectEvent(
      await this.mp.disableCollection(this.sample.address, {from: accounts[0]}),
      'CollectionDisabled'
    );
    // should be zeroed out
    let collectionDetails = await this.mp.collectionState(this.sample.address);
    await expect(
      collectionDetails.status
    ).to.equal(false);
    await expect(
      collectionDetails.royaltyPercent
    ).to.be.bignumber.equal('0');
    await expect(
      collectionDetails.metadataURL
    ).to.equal("");
  });

  // offerTokenForSale

  it('confirms offerTokenForSale requires active contract', async function () {
    // try offerTokenForSale when not enabled, should fail
    await expectRevert(
      this.mp.offerTokenForSale(this.sample.address, 1, getPrice(5), {from: accounts[0]}),
      'Collection must be enabled on this contract by project owner.'
    );
  })

  it('confirms offerTokenForSale requires token ownership', async function () {
    // update collection
    await this.mp.updateCollection(this.sample.address, 5, "ipfs://mynewhash", {from: accounts[0]});
    // try offerTokenForSale as wrong owner, should fail
    await expectRevert(
      this.mp.offerTokenForSale(this.sample.address, 0, getPrice(5), {from: accounts[1]}),
      'You must own the token.'
    );
  });

  it('confirms offerTokenForSale puts new offer for token', async function () {
    // update collection
    await this.mp.updateCollection(this.sample.address, 5, "ipfs://mynewhash", {from: accounts[0]});
    // try offering token as owner, should succeed
    await expectEvent(
      await this.mp.offerTokenForSale(this.sample.address, 0, getPrice(5), {from: accounts[0]}),
      'TokenOffered'
    );
    // token should have valid offer with same numbers
    let tokenDetails = await this.mp.tokenOffers(this.sample.address, 0);
    await expect(
      tokenDetails.isForSale
    ).to.equal(true);
    await expect(
      tokenDetails.tokenIndex
    ).to.be.bignumber.equal('0');
    await expect(
      tokenDetails.seller
    ).to.equal(accounts[0]);
    await expect(
      tokenDetails.minValue
    ).to.be.bignumber.equal(getPrice(5));
    await expect(
      tokenDetails.onlySellTo
    ).to.equal(nullAddress);
  });

  // tokenNoLongerForSale

  it('confirms tokenNoLongerForSale requires active contract', async function () {
    // try tokenNoLongerForSale when contract not enabled, should fail
    await expectRevert(
      this.mp.tokenNoLongerForSale(this.sample.address, 1, {from: accounts[0]}),
      'Collection must be enabled on this contract by project owner.'
    );
  });

  it('confirms tokenNoLongerForSale requires token ownership', async function () {
    // update collection
    await this.mp.updateCollection(this.sample.address, 5, "ipfs://mynewhash", {from: accounts[0]});
    // offer token
    await this.mp.offerTokenForSale(this.sample.address, 0, getPrice(5), {from: accounts[0]});
    // try offerTokenForSale as wrong owner, should fail
    await expectRevert(
      this.mp.tokenNoLongerForSale(this.sample.address, 0, {from: accounts[1]}),
      'You must own the token.'
    );
  });

  it('confirms tokenNoLongerForSale revokes offer for token', async function () {
    // update collection
    await this.mp.updateCollection(this.sample.address, 5, "ipfs://mynewhash", {from: accounts[0]});
    // offer token
    await this.mp.offerTokenForSale(this.sample.address, 0, getPrice(5), {from: accounts[0]});
    // try revoking offer
    await expectEvent(
      await this.mp.tokenNoLongerForSale(this.sample.address, 0, {from: accounts[0]}),
      'TokenNoLongerForSale'
    );
    // offer should be revoked, zeroed out
    let tokenDetails = await this.mp.tokenOffers(this.sample.address, 0);
    await expect(
      tokenDetails.isForSale
    ).to.equal(false);
    await expect(
      tokenDetails.tokenIndex
    ).to.be.bignumber.equal('0');
    await expect(
      tokenDetails.seller
    ).to.equal(accounts[0]);
    await expect(
      tokenDetails.minValue
    ).to.be.bignumber.equal(getPrice(0));
    await expect(
      tokenDetails.onlySellTo
    ).to.equal(nullAddress);
  });

  // enterBidForToken

  it('confirms enterBidForToken requires active contract', async function () {
    // try enterBidForToken when contract not enabled, should fail
    await expectRevert(
      this.mp.enterBidForToken(this.sample.address, 0, {from: accounts[1]}),
      'Collection must be enabled on this contract by project owner.'
    );
  });

  it('confirms enterBidForToken should not require token ownership', async function () {
    // update collection
    await this.mp.updateCollection(this.sample.address, 5, "ipfs://mynewhash", {from: accounts[0]});
    // try enterBidForToken as token owner, should fail
    await expectRevert(
      this.mp.enterBidForToken(this.sample.address, 0, {from: accounts[0]}),
      'Token owner cannot enter bid to self.'
    );
  });

  it('confirms enterBidForToken creates bid for token', async function () {
    // update collection
    await this.mp.updateCollection(this.sample.address, 5, "ipfs://mynewhash", {from: accounts[0]});
    // should be no bid
    await expect(
      (await this.mp.tokenBids(this.sample.address, 0)).hasBid
    ).to.equal(false);
    // try revoking offer
    await expectEvent(
      await this.mp.enterBidForToken(this.sample.address, 0, {from: accounts[1], value: getPrice(1)}),
      'TokenBidEntered'
    );
    // bid should be in
    let bidDetails = await this.mp.tokenBids(this.sample.address, 0);
    await expect(
      bidDetails.hasBid
    ).to.equal(true);
    await expect(
      bidDetails.tokenIndex
    ).to.be.bignumber.equal('0');
    await expect(
      bidDetails.bidder
    ).to.equal(accounts[1]);
    await expect(
      bidDetails.value
    ).to.be.bignumber.equal(getPrice(1));
  });

  // withdrawBidForToken

  it('confirms withdrawBidForToken requires active contract', async function () {
    // try enterBidForToken when contract not enabled, should fail
    await expectRevert(
      this.mp.withdrawBidForToken(this.sample.address, 0, {from: accounts[1]}),
      'Collection must be enabled on this contract by project owner.'
    );
  });

  it('confirms withdrawBidForToken cannot require token ownership', async function () {
    // update collection
    await this.mp.updateCollection(this.sample.address, 5, "ipfs://mynewhash", {from: accounts[0]});
    // create bid
    await this.mp.enterBidForToken(this.sample.address, 0, {from: accounts[1], value: getPrice(1)});
    // try withdrawBidForToken as token owner, should fail
    await expectRevert(
      this.mp.withdrawBidForToken(this.sample.address, 0, {from: accounts[0]}),
      'Token owner cannot enter bid to self.'
    );
  });

  it('confirms withdrawBidForToken should require bid ownership', async function () {
    // update collection
    await this.mp.updateCollection(this.sample.address, 5, "ipfs://mynewhash", {from: accounts[0]});
    // create bid
    await this.mp.enterBidForToken(this.sample.address, 0, {from: accounts[1], value: getPrice(1)});
    // try withdrawBidForToken as not bid owner, should fail
    await expectRevert(
      this.mp.withdrawBidForToken(this.sample.address, 0, {from: accounts[2]}),
      'Only original bidder can withdraw this bid.'
    );
  });

  it('confirms withdrawBidForToken removes bid for token', async function () {
    // update collection
    await this.mp.updateCollection(this.sample.address, 5, "ipfs://mynewhash", {from: accounts[0]});
    // create bid
    await this.mp.enterBidForToken(this.sample.address, 0, {from: accounts[1], value: getPrice(1)});
    // try revoking offer
    await expectEvent(
      await this.mp.withdrawBidForToken(this.sample.address, 0, {from: accounts[1]}),
      'TokenBidWithdrawn'
    );
    // bid should be removed
    let bidDetails = await this.mp.tokenBids(this.sample.address, 0);
    await expect(
      bidDetails.hasBid
    ).to.equal(false);
    await expect(
      bidDetails.tokenIndex
    ).to.be.bignumber.equal('0');
    await expect(
      bidDetails.bidder
    ).to.equal(nullAddress);
    await expect(
      bidDetails.value
    ).to.be.bignumber.equal(getPrice(0));
  });

});

// updateCollection
// disableCollection
// offerTokenForSale
// offerTokenForSaleToAddress
// tokenNoLongerForSale
// enterBidForToken
// withdrawBidForToken
// acceptOfferForToken
// acceptBidForToken
// withdraw
