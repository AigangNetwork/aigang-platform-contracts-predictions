const TestToken = artifacts.require('./moc/TestToken.sol')
const Market = artifacts.require('./Market.sol')
const PrizeCalculator = artifacts.require('./PrizeCalculator.sol')
const ResultStorage = artifacts.require('./ResultStorage.sol')

const BigNumber = web3.BigNumber
contract('Market', accounts => {

  let owner = accounts[0]
  let marketInstance
  let prizeCalculatorInstance
  let resultStorageInstance
  let testTokenInstance

  describe('#prediction', async () => {
    let id
    beforeEach(async () => {
      marketInstance = await Market.new()
      prizeCalculatorInstance = await PrizeCalculator.new()
      resultStorageInstance = await ResultStorage.new()
      testTokenInstance = await TestToken.new()

      await marketInstance.initialize(testTokenInstance.address)

      id = web3.toAscii('18fda5cf3a7a4bc999e3400f49401266')
      const endTime = Date.now() + 60
      const feeInWeis = web3.toWei(12, 'ether')
      const outcomesCount = 2
      const totalTokens = 1000

      await marketInstance.addPrediction(
        id,
        endTime,
        feeInWeis,
        outcomesCount,
        totalTokens,
        resultStorageInstance.address,
        prizeCalculatorInstance.address
      )
    })

    it('add prediction', async () => {
      const prediction = await marketInstance.predictions.call(id)
      const predictionStatus = prediction[2].toNumber()

      assert.equal(1, predictionStatus)
    })

    it('change prediction status', async () => {
      await marketInstance.changePredictionStatus(id, 3)

      const prediction = await marketInstance.predictions.call(id)
      const predictionStatus = prediction[2].toNumber()

      assert.equal(3, predictionStatus)
    })

    it('cancel prediction', async () => {
      await marketInstance.cancel(id)

      const prediction = await marketInstance.predictions.call(id)
      const predictionStatus = prediction[2].toNumber()

      assert.equal(4, predictionStatus)
    })

    it('resolve prediction', async () => {
      const id = 1342
      const endTime = new Date().getTime() / 1000 - 1000
      const feeInWeis = web3.toWei(12, 'ether')
      const outcomesCount = 2
      const totalTokens = 1000

      await marketInstance.addPrediction(
        id,
        endTime,
        feeInWeis,
        outcomesCount,
        totalTokens,
        resultStorageInstance.address,
        prizeCalculatorInstance.address
      )

      const outcomeId = 1
      await resultStorageInstance.setOutcome(id, outcomeId)
      await marketInstance.resolve(id)

      const prediction = await marketInstance.predictions.call(id)
      const predictionStatus = prediction[2].toNumber()

      assert.equal(2, predictionStatus)
    })

    it('payout prediction', async () => {
      // Creating prediction
      predictionIdString = '18fda5cf3a7a4999e3400f4940126432'
      const id = web3.fromAscii(predictionIdString) // result is hex 
      const endTime = new Date().getTime() / 1000 + 2
      const feeInWeis = web3.toWei(12, 'ether')
      const outcomesCount = 2
      const totalTokens = web3.toWei(0, 'ether')

      await marketInstance.addPrediction(
        id,
        endTime,
        feeInWeis,
        outcomesCount,
        totalTokens,
        resultStorageInstance.address,
        prizeCalculatorInstance.address
      )

      // Adding two forecasts
      const firstAmount = web3.toWei(112, 'ether')
      const firstOutcomeId = 1

      var firstOutcomeIdHex = firstOutcomeId.toString(16)
      if (firstOutcomeIdHex.length === 1) {
        firstOutcomeIdHex = "0" + firstOutcomeIdHex;
      }

      const secondAmount = web3.toWei(62, 'ether')
      const secondOutcomeId = 2

      var secondOutcomeIdHex = secondOutcomeId.toString(16)
      if (secondOutcomeIdHex.length === 1) {
        secondOutcomeIdHex = "0" + secondOutcomeIdHex;
      }

      await testTokenInstance.transfer(marketInstance.address, totalTokens)
      await testTokenInstance.transfer(accounts[1], firstAmount)

      await testTokenInstance.approveAndCall(marketInstance.address, firstAmount, id + firstOutcomeIdHex, {
        from: accounts[1]
      })
      await testTokenInstance.approveAndCall(marketInstance.address, secondAmount, id + secondOutcomeIdHex)


      // Sleep to make prediction endTime < now
      await sleep(3000)

      // Setting outcome and making prediction resolved
      await resultStorageInstance.setOutcome(id, firstOutcomeId)
      await marketInstance.resolve(id)

      // Paying out
      await marketInstance.payout(id, 0, 0)

      const forecast = await marketInstance.getForecast(id, firstOutcomeId, 0)

      assert(forecast[2].toNumber() != 0, 'Paid sum is 0')
    })
  })

  describe('#forecast', async () => {
    let predictionId
    let feeInWeis

    beforeEach(async () => {
      marketInstance = await Market.new()
      prizeCalculatorInstance = await PrizeCalculator.new()
      resultStorageInstance = await ResultStorage.new()
      testTokenInstance = await TestToken.new()

      await marketInstance.initialize(testTokenInstance.address)
      predictionIdString = '18fda5cf3a7a4999e3400f4940126432'
      // predictionId = web3.toAscii(predictionIdString) // result is hex 
      predictionId = web3.fromAscii(predictionIdString) // result is hex 
      const endTime = Date.now() + 60
      feeInWeis = web3.toWei(12, 'ether')
      const outcomesCount = 4
      const totalTokens = web3.toWei(1000, 'ether')

      await marketInstance.addPrediction(
        predictionId,
        endTime,
        feeInWeis,
        outcomesCount,
        totalTokens,
        resultStorageInstance.address,
        prizeCalculatorInstance.address
      )

      await testTokenInstance.transfer(marketInstance.address, totalTokens)
    })

    it('create forecast', async () => {
      const firstAmount = web3.toWei(100, 'ether')
      const firstOutcomeId = 1
      var firstOutcomeIdHex = firstOutcomeId.toString(16)
      if (firstOutcomeIdHex.length === 1) {
        firstOutcomeIdHex = "0" + firstOutcomeIdHex;
      }

      const secondAmount = web3.toWei(75, 'ether')
      const secondOutcomeId = 2
      var secondOutcomeIdHex = secondOutcomeId.toString(16)
      if (secondOutcomeIdHex.length === 1) {
        secondOutcomeIdHex = "0" + secondOutcomeIdHex;
      }

      // console.log(`PredictionID: ${predictionId}`)
      // console.log(`OutcomeId : ${firstOutcomeIdHex}`)
      // console.log(`sum : ${predictionId+firstOutcomeIdHex}`)

      await testTokenInstance.transfer(accounts[3], web3.toWei(75, 'ether')) // give tokens to account 3

      await testTokenInstance.approveAndCall(marketInstance.address, firstAmount, predictionId + firstOutcomeIdHex)
      await testTokenInstance.approveAndCall(marketInstance.address, secondAmount, predictionId + secondOutcomeIdHex, {
        from: accounts[3]
      })

      const firstForecast = await marketInstance.getForecast(predictionId, firstOutcomeId, 0)
      const secondForecast = await marketInstance.getForecast(predictionId, secondOutcomeId, 0)

      assert.equal(firstForecast[0], owner)
      assert.equal(firstForecast[1].toNumber(), firstAmount - feeInWeis)
      assert.equal(secondForecast[1].toNumber(), secondAmount - feeInWeis)
    })

    it('refund forecast', async () => {
      // Adding two forecast
      const firstAmount = web3.toWei(112, 'ether')
      const firstOutcomeId = 1

      var firstOutcomeIdHex = firstOutcomeId.toString(16)
      if (firstOutcomeIdHex.length === 1) {
        firstOutcomeIdHex = "0" + firstOutcomeIdHex;
      }

      const secondAmount = web3.toWei(62, 'ether')
      const secondOutcomeId = 2

      var secondOutcomeIdHex = secondOutcomeId.toString(16)
      if (secondOutcomeIdHex.length === 1) {
        secondOutcomeIdHex = "0" + secondOutcomeIdHex;
      }

      await testTokenInstance.transfer(accounts[3], web3.toWei(113, 'ether'))

      await testTokenInstance.approveAndCall(marketInstance.address, firstAmount, predictionId + firstOutcomeIdHex, {
        from: accounts[3]
      })

      await testTokenInstance.approveAndCall(marketInstance.address, secondAmount, predictionId + secondOutcomeIdHex)

      await marketInstance.cancel(predictionId)
      await marketInstance.refund(predictionId, firstOutcomeId, 0, 0)

      const forecast = await marketInstance.getForecast(predictionId, firstOutcomeId, 0)

      assert.equal(forecast[2].toNumber(), firstAmount - feeInWeis)
    })
  })
})

const sleep = milliseconds => {
  return new Promise(resolve => {
    setTimeout(() => {
      resolve()
    }, milliseconds)
  })
}