var FutureETH = artifacts.require("FutureETH");

contract('FutureETH', function(accounts) {

	var sellerAccount = accounts[0]; // "0x627306090abab3a6e1400e9345bc60c78a8bef57"
	var buyerAccount = accounts[1]; // "0xf17f52151ebef6c7334fad080c5704d77216b732"

	it("should have loaded the future price, seconds to wait, and owner balance at initialization.", function() {
		var meta;

		return FutureETH.deployed(600, 1, {from: sellerAccount, value: 8000000000000000}).then(function(instance) {
			meta = instance;
			return meta.getFuturesPrice.call();
		}).then(function(pr) {
			assert.equal(pr.valueOf(), 600, "The price was not 600.");
			return meta.getFuturesSeconds.call();
		}).then(function(sec) {
			assert.equal(sec.valueOf(), 1, "The seconds for the future was not 1.");
			return meta.getSellerBalance.call();
		}).then(function(bal) {
			assert.equal(bal.valueOf(), 8000000000000000, "8 ETH wasn't the owner's deposit");
		})
	});
  	it("should handle refunds for both parties if lock-in not met.", function() {
		var meta;

		return FutureETH.deployed(600, 1, {from: sellerAccount, value: 000000000000000000}).then(function(instance) {
			meta = instance;
		  	meta.receiveFunds({from: sellerAccount, value:8000000000000000});
			return meta.getSellerBalance.call();
		}).then(function(newSellerBalance) {
			assert.equal(newSellerBalance.valueOf(), 8000000000000000, "The seller balance was not 8 ETH.");
			meta.receiveFunds({from: buyerAccount, value:400000000000000});
			return meta.getBuyerBalance.call();
		}).then(function(newBuyerBalance) {
			assert.equal(newBuyerBalance.valueOf(), 400000000000000, "The buyer balance was not 4 ETH.");
			return meta.getFutureStarted.call();
		}).then(function(futureStarted) {
			assert.equal(futureStarted.valueOf(), false, "The future inappropriately started");
			return meta.refund({from: sellerAccount});
	  	}).then(function(result) {
		  	// must go through logs because contract destroyed.
			var amountTransferred = 0;
			var sellerAddress = 0;
			var sellerAmount = 0;
			var buyerAddress = 0;
			var buyerAmount = 0;
			var refundEventFound = false;

			for (var i = 0; i < result.logs.length; i++) {
				var log = result.logs[i];
				JSON.stringify(log);
				
				if (log.event == "RefundEth") {
					// We found the event!
					refundEventFound = true;
					console.log("RefundEvent Found! Log: ", JSON.stringify(log.event));
					sellerAddress = log.event.args.owner;
					buyerAddress = log.event.args.ownerAmount;
					sellerAmount = log.event.args.buyer;
					buyerAmount = log.event.args.buyerAmount;
					break;
				}
			}
			assert.true(refundEventFound, "RefundEvent Not Found");
			assert.equal(sellerAmount.valueOf(), 2000000000000000, "The seller refund was not 2 ETH.");
			assert.equal(buyerAmount.valueOf(), 1000000000000000, "The buyer refund was not 1 ETH.");
			assert.equal(sellerAddress.valueOf(), sellerAccount, "The seller refund address was not correct.");
			assert.equal(buyerAddress.valueOf(), buyerAccount, "The buyer refund address was not correct. ");
	  	});
	});

  	it("should handle future deposits from both parties & lock-in future on equal balances", function() {
		var meta;

		return FutureETH.deployed(600, 1, {from: sellerAccount, value: 0})
	  	.then(function(instance) {
			meta = instance;
			return meta.receiveFunds({from: sellerAccount, value:10000000000000000});
		}).then(function(result) {
			return meta.getSellerBalance.call();
		}).then(function(newSellerBalance) {
			assert.equal(newSellerBalance.valueOf(), 10000000000000000, "The seller balance was not 10 ETH.");
			return meta.receiveFunds({from: buyerAccount, value:10000000000000000});
		}).then(function(result) {
			return meta.getBuyerBalance.call();
		}).then(function(newBuyerBalance) {
			assert.equal(newBuyerBalance.valueOf(), 10000000000000000, "The buyer balance was not 10 ETH.");
			return instance.getFutureStarted.call();
		}).then(function(futureStarted) {
			assert.equal(futureStarted.valueOf(), true, "The future was not considered started");
	  	});
	});

  	it("given a new price of 1000, it should calculate the transfer correctly (2ETH) and send it to the accounts", function() {
		var meta;
		var futuresAmount = 10000000000000000;
		return FutureETH.deployed(600, 1, {from: sellerAccount, value: 0}).then(function(instance) {
			meta = instance;
  			return meta.receiveFunds({from: sellerAccount, value: futuresAmount});
		}).then(function(result) { // use the 'then' functions as alternative to asynch.
			return meta.receiveFunds({from: buyerAccount, value: futuresAmount});
		}).then(function(result) {
			return meta.processFuture(1000);
    	}).then(function(result) {
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
			// calculating right value:
			;

			assert.equal(winningAddress.valueOf(), sellerAccount, "The winning address was not the sellers.");
			assert.equal(amountTransferred.valueOf(), ((futuresAmount * (400)) / 1000), "The amount transferred was not 2 ETH.");
		})
  	});
});
