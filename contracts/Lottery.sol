// Raffle / Lottery

// Enter the lottery (paying some amount)
// Pick a random winner(verifiably random)
// Winner to be selected every X minutes -> completly automated
// Chainlink Oracle -> Randomness, Automated Excution (Chainlink Keeper)

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/automation/interfaces/KeeperCompatibleInterface.sol";

error Lottery__NotEnoughETHEntered();
error Lottery__TransferFailed();
error Lottery__NotOpen();
error Lottery__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);

/**
 * @title A Sample Raffle Contract
 * @author
 * @notice 实现一个不可更改的去中心化的智能合约
 * @dev 实现了Chanlink VRF V2 和Chainlink Keepers
 */
contract Lottery is VRFConsumerBaseV2, KeeperCompatibleInterface {
    /* Type declarations 类型声明*/
    enum RaffleState {
        OPEN,
        CALCULATING
    } // uint256 0 = OPEN, 1 =CALCULATING

    /* state variables 状态变量*/
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

    /* Lootery Variables 抽奖变量，也是状态变量的一部分*/
    address private s_recentWwinner;
    RaffleState private s_raffleState;
    uint256 private s_lastTimeStamp;
    uint256 private immutable i_interval;

    /* Events */
    event RaffleEnter(address indexed player);
    event RequestedRaffleWinner(uint256 indexed requestId);
    event WinnerPicked(address indexed winner);

    /* Functions */
    constructor(
        address vrfCoordinatorV2, //合约地址
        uint256 enteranceFee,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        uint256 interval
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_entranceFee = enteranceFee;
        // 这样便可以使用vrfCoordinator这个合约
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN; // 当启动合约时，应当开放抽奖
        s_lastTimeStamp = block.timestamp; //block.timestamp是一个全局变量，用来获取区块链的当前时间戳
        i_interval = interval;
    }

    function enterRaffle() public payable {
        // require (msg.value > i_entranceFee, "Not enough ETH!")
        if (msg.value < i_entranceFee) {
            revert Lottery__NotEnoughETHEntered();
        }
        // 抽奖未开放时，回滚操作
        if (s_raffleState != RaffleState.OPEN) {
            revert Lottery__NotOpen();
        }
        // 转换一下，因为msg.sender还不是一个payable的地址
        s_players.push(payable(msg.sender));

        // events ： emit an event when we update a dynamic array or mapping
        // 这些被触发的event会被送到智能合约之外的数据存储中
        // Named events with the function name reversed
        emit RaffleEnter(msg.sender);
    }

    /**
     * @dev 这个函数由Chainlink Keepers节点调用，它们会检查upKeepNeeded是否返回true
     * 如果为true，表示需要获取一个新的随机数了
     * 要返回true，应当满足以下条件：
     * 1. 时间间隔应当满足
     * 2. 彩票系统里至少有一个玩家以及一些ETH
     * 3. 我们的订阅中已经注入了Link资金
     * 4. 彩票应当处于open状态
     */
    function checkUpkeep(
        bytes memory /* checkData */ // 由external改成public ，这样我们自己的合约也可以调用checkUpkeep
    ) public override returns (bool upKeepNeeded, bytes memory /* performData */) {
        //block.timestamp - last block timestamp
        bool timePassed = (block.timestamp - s_lastTimeStamp) > i_interval;
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;
        bool isOpen = (RaffleState.OPEN == s_raffleState);
        upKeepNeeded = timePassed && hasPlayers && hasBalance && isOpen;
        // 不需要写return upKeepNeeded，upKeepNeeded自动返回
    }

    // 这个函数将被Chainlink Keepers 网络所调用，这样就可以自动运行而不需要我们手动干预
    // external 比public便宜一点
    // 一旦checkUpkeep返回true，Chainlink节点就会自动调用这个performUpkeep函数
    function performUpkeep(bytes calldata /* performData */) external override {
        // 1.请求一个随机数
        // 2.得到随机数后，用它继续
        // 两个交易过程
        (bool upKeepNeeded, ) = checkUpkeep("");
        if (!upKeepNeeded) {
            revert Lottery__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        // 请求随机数时，状态改为calculating，这样别人就不会参与了
        s_raffleState = RaffleState.CALCULATING;
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
        uint256 /* requestId */,
        uint256[] memory randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWwinner = recentWinner;
        s_raffleState = RaffleState.OPEN; //在从s_players中选出优胜者后，需要重置RaffleState的状态为OPEN；
        s_players = new address payable[](0); //在从s_players中选出优胜者后，需要重置players数组，重置为大小为0的数组
        s_lastTimeStamp = block.timestamp; //重置时间戳
        // 给winner打钱
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Lottery__TransferFailed();
        }
        // 触发事件，查询过去的优胜者的记录
        emit WinnerPicked(recentWinner);
    }

    /* view / pure functions */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayers(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWwinner;
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    // NUM_WORDS是一个常量，存在于字节码中，并没有从storage中读取内容，因此这里是pure函数
    function getNumWords() public pure returns (uint256) {
        return NUM_WORDS; // = return 1;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }

    function getLatestTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRequestConfirmations() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }
}
