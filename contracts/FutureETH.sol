pragma solidity ^0.4.23;


contract FutureETH {
    uint256 constant WEI = 1000000000000000000;
    uint256 futurePrice;
    uint256 futureSeconds;
    uint256 startTime;
    address owner;
    address buyer;
    bool futureStarted;

    mapping (address => uint) public escrow;

    event FundsReceived(address sender, uint256 _value); // funds received from the second person
    event Transfer(address _from, address _to, uint256 _value);
    event FutureStartedEvent(); // when the futuresContract is started
    event FutureCompletedEvent(uint256 expectedPrice, uint256 actualPrice); // when the futures contract is completed
    event Liquidation(uint256 valueLost); // uh oh.
    event RefundEth(address owner, uint ownerAmount, address buyer, uint buyerAmount); // canceled futures contract

    modifier refundable {
        require(!futureStarted);
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

    constructor(uint256 futurePriceToSet, uint256 secondsToWait) public payable {
        owner = msg.sender;
        escrow[msg.sender] = msg.value;
        futurePrice = futurePriceToSet;
        futureSeconds = secondsToWait;
    }

    // fallback function
    function() public payable {
        msg.sender.transfer(msg.value);
        emit Transfer(this, msg.sender, msg.value);
    }

    function receiveFunds() public payable returns (uint newBalance) {
        require(!futureStarted);
        emit FundsReceived(msg.sender, msg.value);
        if (msg.sender == owner) {
            escrow[owner] += msg.value;
        } else if (buyer == 0) {
            buyer = msg.sender;
            escrow[buyer] = msg.value;
        } else {
            // refund the person who sent the ether and is not a participant.
            msg.sender.transfer(msg.value);
            emit Transfer(this, msg.sender, msg.value);
            return 0;
        }

        if (escrow[buyer] >= escrow[owner]) {
            futureStarted = true;
            startTime = now;
            emit FutureStartedEvent();
        }

        return escrow[msg.sender];
    }

    function processFuture(uint actualPrice) public fundingCompleted enoughTimePassed {
        emit FutureCompletedEvent(futurePrice, actualPrice);
        // Msg.value(newPrice-price) / newPrice = quantityOwed
        uint amountToSend = 0;

        // R - E - K - T
        if ((actualPrice*2) <= futurePrice) {
            emit Liquidation(actualPrice*escrow[owner] / 1000000000000000000);
        }

        if (actualPrice > futurePrice) {
            // price went higher than predicted, buyer makes the difference
            amountToSend = (escrow[owner] * (actualPrice-futurePrice)) / actualPrice;
            escrow[owner] += amountToSend;
            escrow[buyer] -= amountToSend;
            buyer.transfer(escrow[buyer]);
            emit Transfer(buyer, owner, amountToSend);
            selfdestruct(owner);
        }
        if (actualPrice < futurePrice) {
            // price went lower than predicted, seller makes the difference
            // solidity can't handle negatives so we reverse the foruma's subtraction
            amountToSend = (escrow[owner] * (futurePrice-actualPrice)) / actualPrice;
            escrow[owner] -= amountToSend;
            escrow[buyer] += amountToSend;
            buyer.transfer(escrow[buyer]);
            emit Transfer(owner, buyer, amountToSend);
            selfdestruct(owner);
        }
    }

    function refund() public onlyOwner refundable {
        if (escrow[buyer] == 0) {
            buyer.transfer(escrow[buyer]);
            emit Transfer(this, buyer, escrow[buyer]);
            emit RefundEth(owner, escrow[owner], buyer, escrow[buyer]);
        } else {
            emit RefundEth(owner, escrow[owner], 0x0, 0);
        }

        emit Transfer(this, owner, address(this).balance);
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
