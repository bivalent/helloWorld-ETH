pragma solidity ^0.4.20;


contract FutureETH {
    uint constant DAY_IN_SECONDS = 86400;
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
    event Liquidation(); // uh oh.
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
        startTime = now;
    }

    function receiveFunds() public payable {
        require(!futureStarted);

        if (msg.sender == owner) {
            escrow[owner] += msg.value;
        } else if (userCount == 1) {
            buyer = msg.sender;
            escrow[buyer] = msg.value;
            userCount = 2;
        } else {
            // refund the person who sent the ether and is not a participant.
            msg.sender.transfer(msg.value);
        }

        if (escrow[owner] >= futureAmount && escrow[buyer] >= futureAmount) {
            futureStarted = true;
            FutureStartedEvent();
        }
    }

    function processFuture(actualPrice) public fundingCompleted enoughTimePassed {
        FutureCompletedEvent(futureAmount, actualPrice);

    }

    function refund() public onlyOwner refundable {
        if (escrow[buyer] == 0) {
            buyer.transfer(escrow[buyer]);
            RefundParticipants(escrow[owner], escrow[buyer]);
        } else {
            RefundParticipants(escrow[owner], 0);
        }

        selfdestruct(owner);
    }


}
