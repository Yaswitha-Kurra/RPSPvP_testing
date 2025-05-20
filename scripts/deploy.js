const quais = require('quais')
const RPSPvPJson = require('../artifacts/contracts/RPSPvP.sol/RPSPvP.json')
const { deployMetadata } = require("hardhat");
require('dotenv').config()

// Pull contract arguments from .env
//const tokenArgs = [process.env.ERC20_NAME, process.env.ERC20_SYMBOL, quais.parseUnits(process.env.ERC20_INITIALSUPPLY)]

async function deployMyRPSPvP() {
  // Config provider, wallet, and contract factory
  const provider = new quais.JsonRpcProvider(hre.network.config.url, undefined, { usePathing: true })
  const wallet = new quais.Wallet(hre.network.config.accounts[0], provider)
  const ipfsHash = await deployMetadata.pushMetadataToIPFS("RPSPvP")
  const RPSPvP = new quais.ContractFactory(RPSPvPJson.abi, RPSPvPJson.bytecode, wallet, ipfsHash)

  // Broadcast deploy transaction
  const MyRPSPvP_transaction = await RPSPvP.deploy()
  console.log('Transaction broadcasted: ', MyRPSPvP_transaction.deploymentTransaction().hash)

  // Wait for contract to be deployed
  await MyRPSPvP_transaction.waitForDeployment()
  console.log('Contract deployed to: ', await MyRPSPvP_transaction.getAddress())
}

deployMyRPSPvP()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })