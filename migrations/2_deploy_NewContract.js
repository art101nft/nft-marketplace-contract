var NewContract = artifacts.require("NewContract");

module.exports = function(deployer) {
  deployer.deploy(NewContract);
};
