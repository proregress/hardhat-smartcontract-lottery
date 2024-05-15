// Raffle / Lottery

// Enter the lottery (paying some amount)
// Pick a random winner(verifiably random)
// Winner to be selected every X minutes -> completly automated
// Chainlink Oracle -> Randomness, Automated Excution (Chainlink Keeper)

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

error Lottery_NotEnoughETHEntered();

contract Lottery is VRFConsumerBaseV2 {
    /* stage variables */
    // 最低参与金额，原本是一个storage变量
    // 因为只在构造函数中设置它一次，所以可以将其创建为一个constant或则和immutable变量
    uint256 private immutable i_entranceFee;
    // storage变量，因为需要一直对玩家增加或删减
    // payable：最终会有一位玩家胜出，需要把钱支付给他们
    address payable[] private s_players;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint16 private constant NUM_WORDS = 1;

    /* Events */
    event RaffleEnter(address indexed player);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        address vrfCoordinatorV2,
        uint256 enteranceFee,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_entranceFee = enteranceFee;
        // 这样便可以使用vrfCoordinator这个合约
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
    }

    function enterRaffle() public payable {
        // require (msg.value > i_entranceFee, "Not enough ETH!")
        if (msg.value < i_entranceFee) {
            revert Lottery_NotEnoughETHEntered();
        }
        // 转换一下，因为msg.sender还不是一个payable的地址
        s_players.push(payable(msg.sender));

        // events ： emit an event when we update a dynamic array or mapping
        // 这些被触发的event会被送到智能合约之外的数据存储中
        // Named events with the function name reversed
        emit RaffleEnter(msg.sender);
    }

    // 这个函数将被Chainlink Keepers 网络所调用，这样就可以自动运行而不需要我们手动干预
    // external 比public便宜一点
    function requestRandomWinner() external {
        // 1.请求一个随机数
        // 2.得到随机数后，用它继续
        // 两个交易过程
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, // keyhash = gas lane, gas 通道
            i_subscriptionId, // 订阅id，即一个用于请求随机数并支付Oracle gas预言机gas所需link 的订阅id
            REQUEST_CONFIRMATIONS, //等待区块确认数
            i_callbackGasLimit, //指回调本合约的fulfillRandomWords请求时对应的gas使用上限
            NUM_WORDS //想要获取的随机数数量
        );

        // 使用requestId触发事件
        emit RequestedRaffleWinner(requestId);
    }

    // 填充随机数，从这里获取多个随机数
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {}

    /* view / pure functions */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayers(uint256 index) public view returns (address) {
        return s_players[index];
    }
}
