var FutureETH = artifacts.require("FutureETH");

var price = 600;
var seconds = 1;
module.exports = function(deployer) {
  deployer.deploy(FutureETH, price, seconds);
};
