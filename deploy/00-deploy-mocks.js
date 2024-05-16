const { network, ethers } = require("hardhat")
const { developmenyChains } = require("../helper-hardhat-config")

const BASE_FEE = ethers.utils.parseEther("0.25") //保底费用，每次请求花费0.25LINK
const GAS_PRICE_LINK = 1e9 // link per gas // 这是一个计算值，基于所在链gas价格的计算值

module.exports = async function ({ getNamesAccounts, deployments }) {
    const { deployer } = await getNamesAccounts()
    const { deploy, log } = deployments
    //只将mock部署在开发链上
    const chainId = network.config.chainId
    const args = [BASE_FEE, GAS_PRICE_LINK]

    if (developmenyChains.includes(network.name)) {
        log("Local network detected! Deploying mocks....")
        // 部署一个模拟的vrfCoordinator, deploy a mock vrfCoordinator
        // 首先要获得一个vrfCoordinator： contracts/test/VRFCoordinatorV2Mock.sol编译成功
        await deploy("VRFCoordinatorV2Mock", {
            from: deployer,
            log: true,
            args: args,
        })
        log("Mocks Deployed!")
        log("-----------------------------------------------")
    }
}

module.exports.tags = ["all", "mocks"]
