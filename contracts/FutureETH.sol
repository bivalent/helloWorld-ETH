pragma solidity ^0.4.20;


contract FutureETH {
    uint constant DAY_IN_SECONDS = 86400;
    uint256 constant WEI = 1000000000000000000;
    uint256 futurePrice;
    uint256 futureSeconds;
    uint256 startTime;
    address owner;
    address buyer;
    uint8 userCount;
    bool futureStarted;
    bool futureCompleted;

    mapping (address => uint) public escrow;

    event FundsReceived(address sender, uint256 _value); // funds received from the second person
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event FutureStartedEvent(); // when the futuresContract is started
    event FutureCompletedEvent(uint256 expectedPrice, uint256 actualPrice); // when the futures contract is completed
    event Liquidation(uint256 valueLost); // uh oh.
    event RefundEth(address owner, uint ownerAmount, address buyer, uint buyerAmount); // canceled futures contract

    modifier refundable {
        require(!futureStarted || futureCompleted);
        _;
    }

    modifier fundingCompleted {
        require(escrow[buyer] >= escrow[owner]);
        _;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    modifier enoughTimePassed {
        require(now-startTime >= futureSeconds);
        _;
    }

    function FutureETH(uint256 futurePriceToSet, uint256 secondsToWait) public payable {
        owner = msg.sender;
        escrow[msg.sender] = msg.value;
        userCount = 1;
        futurePrice = futurePriceToSet;
        futureSeconds = secondsToWait;
    }

    // fallback function
    function() public payable {
        msg.sender.transfer(msg.value);
        Transfer(this, msg.sender, msg.value);
    }

    function receiveFunds() public payable returns (uint newBalance) {
        require(!futureStarted);
        FundsReceived(msg.sender, msg.value);
        if (msg.sender == owner) {
            escrow[owner] += msg.value;
        } else if (userCount == 1) {
            buyer = msg.sender;
            escrow[buyer] = msg.value;
            userCount = 2;
        } else {
            // refund the person who sent the ether and is not a participant.
            msg.sender.transfer(msg.value);
            Transfer(this, msg.sender, msg.value);
            return 0;
        }

        if (escrow[buyer] >= escrow[owner]) {
            futureStarted = true;
            startTime = now;
            FutureStartedEvent();
        }

        return escrow[msg.sender];
    }

    function processFuture(uint actualPrice) public fundingCompleted enoughTimePassed {
        FutureCompletedEvent(futurePrice, actualPrice);
        // Msg.value(newPrice-price) / newPrice = quantityOwed
        uint amountToSend = 0;

        // R - E - K - T
        if ((actualPrice*2) <= futurePrice) {
            Liquidation(actualPrice*escrow[owner] / 1000000000000000000);
        }

        if (actualPrice > futurePrice) {
            // price went higher than predicted, buyer makes the difference
            amountToSend = (escrow[owner] * (actualPrice-futurePrice)) / actualPrice;
            escrow[owner] += amountToSend;
            escrow[buyer] -= amountToSend;
            buyer.transfer(escrow[buyer]);
            Transfer(buyer, owner, amountToSend);
            selfdestruct(owner);
        }
        if (actualPrice < futurePrice) {
            // price went lower than predicted, seller makes the difference
            // solidity can't handle negatives so we reverse the foruma's subtraction
            amountToSend = (escrow[owner] * (futurePrice-actualPrice)) / actualPrice;
            escrow[owner] -= amountToSend;
            escrow[buyer] += amountToSend;
            buyer.transfer(escrow[buyer]);
            Transfer(owner, buyer, amountToSend);
            selfdestruct(owner);
        }
    }

    function refund() public onlyOwner refundable {
        if (escrow[buyer] == 0) {
            buyer.transfer(escrow[buyer]);
            Transfer(this, buyer, escrow[buyer]);
            RefundEth(owner, escrow[owner], buyer, escrow[buyer]);
        } else {
            RefundEth(owner, escrow[owner], 0x0, 0);
        }

        Transfer(this, owner, address(this).balance);
        selfdestruct(owner);
    }

    function getSecondsLeft() public view returns (uint) {
        if (now-startTime >= futureSeconds) {
            return 0;
        } else {
            return startTime+(futureSeconds)-now;
        }
    }

    function getSellerBalance() public view returns(uint) {
        return escrow[owner];
    }

    function getBuyerBalance() public view returns (uint) {
        return escrow[buyer];
    }

    function getFutureAmount() public view returns (uint) {
        return escrow[buyer];
    }

    function getFuturesPrice() public view returns (uint) {
        return futurePrice;
    }

    function getFuturesSeconds() public view returns (uint) {
        return futureSeconds;
    }

    function getFutureStarted() public view returns (bool) {
        return futureStarted;
    }
}
