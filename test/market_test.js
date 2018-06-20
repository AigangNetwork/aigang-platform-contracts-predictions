const TestToken = artifacts.require('./moc/TestToken.sol')
const Market = artifacts.require('./Market.sol')
const PrizeCalculator = artifacts.require('./PrizeCalculator.sol')
const ResultStorage = artifacts.require('./ResultStorage.sol')

const BigNumber = web3.BigNumber
const assert = require('chai').assert

//import { latestBlock, getTime } from "./utils.js"

let testToken

contract('Market', ([miner, owner, user1, user2]) => {
  let token
  let market
  let prizeCalculator
  let resultStorage

  let addresses = [
    '0xD7dFCEECe5bb82F397f4A9FD7fC642b2efB1F565',
    '0x501AC3B461e7517D07dCB5492679Cc7521AadD42',
    '0xDc76C949100FbC502212c6AA416195Be30CE0732',
    '0x2C49e8184e468F7f8Fb18F0f29f380CD616eaaeb',
    '0xB3d3c445Fa47fe40a03f62d5D41708aF74a5C387',
    '0x34D468BFcBCc0d83F4DF417E6660B3Cf3e14F62A',
    '0x27E6FaE913861180fE5E95B130d4Ae4C58e2a4F4',
    '0x7B199FAf7611421A02A913EAF3d150E359718C2B',
    '0x086282022b8D0987A30CdD508dBB3236491F132e',
    '0xdd39B760748C1CA92133FD7Fc5448F3e6413C138',
    '0x0868411cA03e6655d7eE957089dc983d74b9Bf1A',
    '0x4Ec993E1d6980d7471Ca26BcA67dE6C513165922'
  ]

  it('#initialize accepts token', async function() {
    const market = await Market.new()
    market.initialize('0x0000000000000000000000000000000000000123')
    const token = await market.token()
    assert.equal(token, '0x0000000000000000000000000000000000000123', '== token address')
  })

  before(async function() {
    // runs before all tests in this block
    testToken = await TestToken.new()
  })
})
