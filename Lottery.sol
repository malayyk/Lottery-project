//SPDX-License-Identifier: MIT
pragma solidity >0.6.0 <=0.9.0;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract Lottery is VRFConsumerBaseV2 {
    AggregatorV3Interface internal ethpriceFeed;

    VRFCoordinatorV2Interface internal COORDINATOR;
    LinkTokenInterface internal LINKTOKEN;

    address payable[] public participants;
    uint256 public EntranceFeeUsd;

    address vrfCoordinator = 0x6168499c0cFfCaCD319c818142124B7A15E857ab;
    address link = 0x01BE23585060835E02B77ef475b0Cc51aA1e0709;

    bytes32 keyHash =
        0xd89b2bf150e3b9e13446986e571fb9cab24b13cea0a43ea20a6049a85cc807cc;

    address[] public recentWinners;
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor(address _pricefeedaddress, uint64 subscriptionId)
        VRFConsumerBaseV2(vrfCoordinator)
    {
        owner = msg.sender;
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        LINKTOKEN = LinkTokenInterface(link);

        EntranceFeeUsd = 50 * (10**18);
        ethpriceFeed = AggregatorV3Interface(_pricefeedaddress);
        Lottery_State = LotteryState.CLOSED;
        see_subscriptionId = subscriptionId;
    }

    enum LotteryState {
        OPEN,
        CLOSED,
        CALCLATING_WINNER
    }
    LotteryState public Lottery_State;

    uint32 callbackGasLimit = 100000;

    uint32 numWords = 1;
    uint16 requestConfirmations = 3;
    uint64 see_subscriptionId;

    uint256 public see_randomWords;

    function getEntranceFee() public view returns (uint256) {
        (, int256 price, , , ) = ethpriceFeed.latestRoundData();
        uint256 adjustedPrice = uint256(price) * 10**10;

        uint256 costToEnter = ((EntranceFeeUsd * 10**18) / adjustedPrice);
        return costToEnter;
    }

    function startLottery() public onlyOwner {
        require(
            Lottery_State == LotteryState.CLOSED,
            "Cant start a new lottery currently!"
        );
        Lottery_State = LotteryState.OPEN;
    }

    function enterLottery() public payable {
        require(Lottery_State == LotteryState.OPEN);
        require(msg.value >= getEntranceFee() + 1000, "Not enought eth!");
        participants.push(payable(msg.sender));
    }

    function endLottery() public onlyOwner {
        require(Lottery_State == LotteryState.OPEN);
        Lottery_State = LotteryState.CALCLATING_WINNER;
        uint256 requestId = COORDINATOR.requestRandomWords(
            keyHash,
            see_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords)
        internal
        override
    {
        require(
            Lottery_State == LotteryState.CALCLATING_WINNER,
            "Lottery hasn't ended yet"
        );
        require(randomWords[0] > 0, "Not yet returned");
        see_randomWords = randomWords[0];

        uint256 indexOfWinner = see_randomWords % participants.length;
        address payable recentWinner = participants[indexOfWinner];
        recentWinner.transfer(address(this).balance);
        participants = new address payable[](0);
        recentWinners.push(recentWinner);

        Lottery_State = LotteryState.CLOSED;
    }
}
