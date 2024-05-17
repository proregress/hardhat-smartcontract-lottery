// mock

const { ethers } = require("hardhat")

const networkConfig = {
    11155111: {
        name: "sepolia",
        vrfCoordinatorV2: "0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625",
        // 创建一个基于区块链的entranceFee
        entranceFee: ethers.utils.parseEther("0.01"),
        gasLane: "0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae",
        subscriptionId: "0",
        callbackGasLimit: "500000", // 500,000 gas
        interval: "30", // 30 秒
    },
    31337: {
        name: "hardhat",
        entranceFee: ethers.utils.parseEther("0.01"),
        gasLane: "0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae",
        subscriptionId: "0",
        callbackGasLimit: "500000", // 500,000 gas
        interval: "30", // 30 秒
    },
}

// 开发链
const developmentChains = ["hardhat", "localhost"]

module.exports = {
    networkConfig,
    developmentChains,
}
