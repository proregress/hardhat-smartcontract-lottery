//用来部署Lottery合约

const { network, ethers } = require("hardhat")
const { developmentChains, networkConfig } = require("../helper-hardhat-config")

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId
    let vrfCoordinatorV2Address, subscriptionId

    if (developmentChains.includes(network.name)) {
        // 在开发链上，需要获取mock合约
        const vrfCoordinatorV2Mock = await ethers.getContract("VERCoordinatorV2Mock")
        vrfCoordinatorV2Address = vrfCoordinatorV2Mock.address
        // 在开发链上建立订阅，以获得subscriptionId
        const transactionResponse = await vrfCoordinatorV2Mock.createSubscription()
        const transactionReceipt = await transactionResponse.wait(1)
        subscriptionId = transactionReceipt.events[0].args.subId
        // 资助订阅
        // 在真实网络上，需要有Link或代币才能资助这个订阅
        // 当前的mock版本允许在没有link 代币的情况下资助订阅
        await vrfCoordinatorV2Mock.fundSubScription(subscriptionId)
    } else {
        // 不在开发链、本地网络上的话，vrfCoordinatorV2Address就是来源于networkconfig
        vrfCoordinatorV2Address = networkConfig[chainId]["vrfCoordinatiorV2"]
    }

    const entranceFee = networkConfig[chainId]["entranceFee"]
    const gasLane = networkConfig[chainId]["gasLane"]
    const args = [vrfCoordinatorV2Address, entranceFee, gasLane]
    const lottery = await deploy("Lottery", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1,
    })
}
