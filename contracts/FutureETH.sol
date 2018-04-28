pragma solidity ^0.4.20;


contract FutureETH {
    uint constant DAY_IN_SECONDS = 86400;
    uint256 constant WEI = 1000000000000000000;
    uint256 futurePrice;
    uint256 futureDays;
    uint256 startTime;
    address owner;
    address buyer;
    uint8 userCount;
    bool futureStarted;
    bool futureCompleted;

    mapping (address => uint) escrow;

    event FundsReceived(address sender, uint256 _value); // funds received from the second person
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event FutureStartedEvent(); // when the futuresContract is started
    event FutureCompletedEvent(uint256 expectedPrice, uint256 actualPrice); // when the futures contract is completed
    event Liquidation(uint256 valueLost); // uh oh.
    event RefundParticipants(uint256 ownerAmount, uint256 buyerAmount); // canceled futures contract

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
        require(now-startTime >= futureDays*DAY_IN_SECONDS);
        _;
    }

    function FutureETH(uint256 futurePriceToSet, uint256 daysToWait) public payable {
        owner = msg.sender;
        escrow[msg.sender] = msg.value;
        userCount = 1;
        futurePrice = futurePriceToSet;
        futureDays = daysToWait;
    }

    function receiveFunds() public payable {
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
        }

        if (escrow[buyer] >= escrow[owner]) {
            futureStarted = true;
            startTime = now;
            FutureStartedEvent();
        }
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
            Transfer(this, buyer, escrow[buyer]);
            Transfer(this, owner, address(this).balance);
            selfdestruct(owner);
        }
        if (actualPrice < futurePrice) {
            // price went lower than predicted, seller makes the difference
            // solidity can't handle negatives so we reverse the foruma's subtraction
            amountToSend = (escrow[owner] * (futurePrice-actualPrice)) / actualPrice;
            escrow[owner] -= amountToSend;
            escrow[buyer] += amountToSend;
            buyer.transfer(escrow[buyer]);
            Transfer(this, buyer, escrow[buyer]);
            Transfer(this, owner, address(this).balance);
            selfdestruct(owner);
        }
    }

    function refund() public onlyOwner refundable {
        if (escrow[buyer] == 0) {
            buyer.transfer(escrow[buyer]);
            Transfer(this, buyer, escrow[buyer]);
            RefundParticipants(escrow[owner], escrow[buyer]);
        } else {
            RefundParticipants(escrow[owner], 0);
        }

        Transfer(this, owner, address(this).balance);
        selfdestruct(owner);
    }
}
