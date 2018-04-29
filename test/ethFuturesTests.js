var FutureETH = artifacts.require("FutureETH");

contract('FutureETH', function(accounts) {
	var buyerAccount = accounts[0]; // "0x627306090abab3a6e1400e9345bc60c78a8bef57"
	var sellerAccount = accounts[1]; // "0xf17f52151ebef6c7334fad080c5704d77216b732"
	var Futures1 = FutureETH.deployed(600, 1, {value: 8000000000000000000});

	it("should have loaded the future price, seconds to wait, and owner balance at initialization.", function() {
		return (Futures1.getFuturesPrice.call(), Futures1.getFuturesSeconds.call(), Futures1.getSellerBalance.call())
		.then(function(price, seconds, sellerBalance) {
			assert.equal(price.valueOf(), 600, "The price was not 600.");
			assert.equal(seconds.valueOf(), 1, "The seconds for the future was not 1.");
			assert.equal(sellerBalance.valueOf(), 5000000000000000000, "5 ETH wasn't the owner's deposit");
  		});
	});
  	it("should handle refunds for both parties if lock-in not met.", function() {
	  	return (instance.receiveFunds({from: sellerAccount, value:2000000000000000000}), instance.receiveFunds({from: buyerAccount, value:1000000000000000000}), instance.getFutureStarted.call())
	  	.then(function(sellerBalance, buyerBalance, futureStarted) {
			assert.equal(sellerBalance.valueOf(), 2000000000000000000, "The seller balance was not 2 ETH.");
			assert.equal(buyerBalance.valueOf(), 1000000000000000000, "The buyer balance was not 1 ETH.");
			//assert.equal(futureStarted.valueOf(), true, "The future was not considered started");
			return instance.refund({from: sellerAccount})
  	}).then(function(result) {
	  	// must go through logs because contract destroyed.
		var amountTransferred = 0;
		var sellerAddress = 0;
		var sellerAmount = 0;
		var buyerAddress = 0;
		var buyerAmount = 0;

		for (var i = 0; i < result.logs.length; i++) {
			var log = result.logs[i];

			if (log.event == "RefundEth") {
				// We found the event!
				sellerAddress = log.event.args.owner;
				buyerAddress = log.event.args.ownerAmount;
				sellerAmount = log.event.args.buyer;
				buyerAmount = log.event.args.buyerAmount;
				break;
			}
		}

		assert.equal(sellerAmount.valueOf(), 2000000000000000000, "The seller refund was not 2 ETH.");
		assert.equal(buyerAmount.valueOf(), 1000000000000000000, "The buyer refund was not 1 ETH.");
		assert.equal(sellerAddress.valueOf(), sellerAccount, "The seller refund address was not correct. Address: " + sellerAccount);
		assert.equal(buyerAddress.valueOf(), buyerAccount, "The buyer refund address was not correct. Address: " + buyerAccount);
  	});
  });
  it("should handle future deposits from both parties & lock-in future on equal balances", function() {
	// redeploy contract after destroying it previously
	Futures1 = FutureETH.deployed(600, 1, {from: sellerAccount, value: 0});
	return Futures1
  	.then(function(instance) {
		return instance.receiveFunds({from: sellerAccount, value:10000000000000000000}), instance.receiveFunds({from: buyerAccount, value:10000000000000000000}), instance.getFutureStarted.call();
  	}).then(function(sellerBalance, buyerBalance, futureStarted) {
		assert.equal(sellerBalance.valueOf(), 10000000000000000000, "The seller balance was not 10 ETH.");
		assert.equal(buyerBalance.valueOf(), 10000000000000000000, "The buyer balance was not 10 ETH.");
		assert.equal(futureStarted.valueOf(), true, "The future was not considered started");
  	});
});


  it("given a new price of 1000, it should calculate the transfer correctly and send it to the accounts", function() {
	return Futures1.processFuture(1000, {from: sellerAccount}).then(function(result) {
		// 2 eth transferred from buyer to seller.
		// We can loop through result.logs to see if we triggered the Transfer events.
		var amountTransferred = 0;
  	  	var winningAddress = 0;

		for (var i = 0; i < result.logs.length; i++) {
			var log = result.logs[i];

			if (log.event == "Transfer") {
				// We found the event!
				amountTransferred = log.event.args._value;
				winningAddress = log.event.args._to;
				break;
			}
		}

		assert.equal(amountTransferred.valueOf(), 2000000000000000000, "The amount transferred was not 2 ETH. Transferred: " + amountTransferred);
		assert.equal(winningAddress.valueOf(), sellerAccount, "The winning address was not the sellers. Received: " + winningAddress);
	})
  });
});
