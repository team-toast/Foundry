module BucketSaleTestBase

open TestBase
open System.Numerics
open FsUnit.Xunit
open DAIHard.Contracts.BucketSale.ContractDefinition
open Constants

let DAI =
    let abi = Abi("../../../../build/contracts/TestToken.json")

    let deployTxReceipt =
        ethConn.DeployContractAsync abi
            [| "MCD DAI stable coin"
               "DAI"
               ethConn.Account.Address
               bucketSupply * bucketCount * BigInteger(100UL) |]
        |> runNow

    let result = ContractPlug(ethConn, abi, deployTxReceipt.ContractAddress)
    result.Query "balanceOf" [| ethConn.Account.Address |] |> should equal (bucketSupply * bucketCount * BigInteger(100UL) * BigInteger(1000000000000000000UL))
    result


let FRY =
    let abi = Abi("../../../../build/contracts/TestToken.json")

    let deployTxReceipt =
        ethConn.DeployContractAsync abi
            [| "Foundry logistics token"
               "FRY"
               ethConn.Account.Address
               BigInteger(1000000UL) |]
        |> runNow

    let result = ContractPlug(ethConn, abi, deployTxReceipt.ContractAddress)
    result


let referrerReward amount =
    ((amount / BigInteger 1000000000000000000UL) + BigInteger 10000UL)
        

let bucketSale =
    let abi = Abi("../../../../build/contracts/BucketSale.json")

    let deployTxReceipt =
        ethConn.DeployContractAsync abi
            [| ethConn.Account.Address; startOfSale; bucketPeriod; bucketSupply; bucketCount; FRY.Address; DAI.Address |]
        |> runNow

    ContractPlug(ethConn, abi, deployTxReceipt.ContractAddress)


let seedBucketWithFries() =
    let frySupplyBefore = FRY.Query "balanceOf" [| bucketSale.Address |]
    let transferFryTxReceipt =
        FRY.ExecuteFunction "transfer"
            [| bucketSale.Address
               bucketSupply * bucketCount |]
    transferFryTxReceipt |> shouldSucceed
    FRY.Query "balanceOf" [| bucketSale.Address |] |> should equal (frySupplyBefore + bucketSupply * bucketCount)


let seedWithDAI (recipient:string) (amount:BigInteger) =
    let balanceBefore = DAI.Query "balanceOf" [| recipient |] 
    let transferDaiTxReceipt = DAI.ExecuteFunction "transfer" [| recipient; amount |]
    transferDaiTxReceipt |> shouldSucceed
    DAI.Query "balanceOf" [| recipient |] |> should equal (balanceBefore + amount)

let enterBucket sender buyer bucketToEnter valueToEnter referrer =
    let approveDaiTxReceipt = DAI.ExecuteFunction "approve" [| bucketSale.Address; valueToEnter |] // Should we call this DAI, or increase the scope of the audit to any ERC20 token? And call it TokenSoldFor?
    approveDaiTxReceipt |> shouldSucceed

    // unneeded?
    //let currentBucket = bucketSale.Query "currentBucket" [||]
    let referrerReferredTotalBefore = bucketSale.Query "referredTotal" [| referrer |]
    let referrerRewardPercBefore = bucketSale.Query "referrerReferralRewardPerc" [| referrer |]
    let calculatedReferrerRewardPercBefore = referrerReward referrerReferredTotalBefore
    referrerRewardPercBefore |> should equal calculatedReferrerRewardPercBefore
    let senderDaiBalanceBefore = DAI.Query "balanceOf" [| sender |]
    let bucketDaiBalanceBefore = DAI.Query "balanceOf" [| bucketSale.Address |]
    let buyForBucketBefore = bucketSale.QueryObj<BuysOutputDTO> "buys" [| bucketToEnter; buyer |]
    // The following 3 var names are confusing to me; discuss.
    let buyerRewardBuyForBucketBefore = bucketSale.QueryObj<BuysOutputDTO> "buys" [| bucketToEnter + BigInteger.One; buyer |]
    let referrerRewardBuyForBucketBefore = bucketSale.QueryObj<BuysOutputDTO> "buys" [| bucketToEnter + BigInteger.One; referrer |]
    let bucketBefore = bucketSale.QueryObj<BucketsOutputDTO> "buckets" [| bucketToEnter |]
    let referralBucketBefore = bucketSale.QueryObj<BucketsOutputDTO> "buckets" [| bucketToEnter + BigInteger.One |]

    // act
    let receipt = bucketSale.ExecuteFunction "enter" [| buyer; bucketToEnter; valueToEnter; referrer |]

    // assert
    receipt |> shouldSucceed

    // event validation
    let referredTotalAfter = bucketSale.Query "referredTotal" [| referrer |]
    referredTotalAfter |> should equal (referrerReferredTotalBefore + valueToEnter)
    let calculatedReferrerRewardPercAfter = referrerReward referredTotalAfter
    // ^ calculated, or after? after to me implies the state of the contract; calculated implies what we should expect
    // Apply to buyerReward and referrerReward too
    let referrerRewardPercAfter = bucketSale.Query "referrerReferralRewardPerc" [| referrer |]
    referrerRewardPercAfter |> should equal calculatedReferrerRewardPercAfter
    let buyerReward = valueToEnter / BigInteger 10UL
    let referrerReward = valueToEnter * calculatedReferrerRewardPercAfter / BigInteger 100000

    let enteredEvent = receipt |> decodeFirstEvent<EnteredEventDTO>
    if referrer <> EthAddress.Zero then
        enteredEvent.BucketId |> should equal bucketToEnter
        enteredEvent.Buyer |> shouldEqualIgnoringCase buyer
        enteredEvent.BuyerReferralReward |> should equal buyerReward
        enteredEvent.Sender |> shouldEqualIgnoringCase sender
        enteredEvent.Referrer |> shouldEqualIgnoringCase referrer
        enteredEvent.ReferrerReferralReward |> should equal referrerReward
        enteredEvent.ValueEntered |> should equal valueToEnter
    else
        enteredEvent.BucketId |> should equal bucketToEnter
        enteredEvent.Buyer |> shouldEqualIgnoringCase buyer
        enteredEvent.BuyerReferralReward |> should equal BigInteger.Zero
        enteredEvent.Sender |> shouldEqualIgnoringCase sender
        enteredEvent.Referrer |> shouldEqualIgnoringCase EthAddress.Zero // for clarity, right?
        enteredEvent.ReferrerReferralReward |> should equal BigInteger.Zero
        enteredEvent.ValueEntered |> should equal valueToEnter

    // state validation
    // unchanged state
    bucketSale.Query "owner" [||] |> shouldEqualIgnoringCase ethConn.Account.Address
    bucketSale.Query "startOfSale" [||] |> should equal startOfSale
    bucketSale.Query "bucketPeriod" [||] |> should equal bucketPeriod
    bucketSale.Query "bucketSupply" [||] |> should equal bucketSupply
    bucketSale.Query "bucketCount" [||] |> should equal bucketCount
    bucketSale.Query "tokenOnSale" [||] |> shouldEqualIgnoringCase FRY.Address
    bucketSale.Query "tokenSoldFor" [||] |> shouldEqualIgnoringCase DAI.Address

    // changed state
    let senderDaiBalanceAfter = DAI.Query "balanceOf" [| sender |]
    senderDaiBalanceAfter |> should equal (senderDaiBalanceBefore - valueToEnter)
    let bucketSaleDaiBalanceAfter = DAI.Query "balanceOf" [| bucketSale.Address |]
    bucketSaleDaiBalanceAfter |> should equal (bucketDaiBalanceBefore + valueToEnter)

    let buyForBucketAfter = bucketSale.QueryObj<BuysOutputDTO> "buys" [| bucketToEnter; buyer |]
    buyForBucketAfter.ValueEntered |> should equal (buyForBucketBefore.ValueEntered + valueToEnter)
    buyForBucketAfter.BuyerTokensExited |> should equal BigInteger.Zero // Should move up to 'unchanged state' block? Hmm

    let bucketAfter = bucketSale.QueryObj<BucketsOutputDTO> "buckets" [| bucketToEnter |]
    bucketAfter.TotalValueEntered |> should equal (bucketBefore.TotalValueEntered + valueToEnter)

    if referrer <> EthAddress.Zero then
        let buyerRewardBuyForBucketAfter = bucketSale.QueryObj<BuysOutputDTO> "buys" [| bucketToEnter + BigInteger.One; buyer |]
        buyerRewardBuyForBucketAfter.ValueEntered |> should equal (buyerRewardBuyForBucketBefore.ValueEntered + buyerReward)
        buyerRewardBuyForBucketAfter.BuyerTokensExited |> should equal BigInteger.Zero

        let referrerRewardBuyForBucketAfter = bucketSale.QueryObj<BuysOutputDTO> "buys" [| bucketToEnter + BigInteger.One; referrer |]
        referrerRewardBuyForBucketAfter.ValueEntered |> should equal (referrerRewardBuyForBucketBefore.ValueEntered + referrerReward)
        referrerRewardBuyForBucketAfter.BuyerTokensExited |> should equal BigInteger.Zero

        let referralBucketAfter = bucketSale.QueryObj<BucketsOutputDTO> "buckets" [| bucketToEnter + BigInteger.One |]
        referralBucketAfter.TotalValueEntered |> should equal (referralBucketBefore.TotalValueEntered + referrerReward + buyerReward)
    else
        let buyerRewardBuyForBucketAfter = bucketSale.QueryObj<BuysOutputDTO> "buys" [| bucketToEnter + BigInteger.One; buyer |]
        buyerRewardBuyForBucketAfter.ValueEntered |> should equal BigInteger.Zero
        buyerRewardBuyForBucketAfter.BuyerTokensExited |> should equal BigInteger.Zero

        let referrerRewardBuyForBucketAfter = bucketSale.QueryObj<BuysOutputDTO> "buys" [| bucketToEnter + BigInteger.One; referrer |]
        buyerRewardBuyForBucketAfter.ValueEntered |> should equal BigInteger.Zero
        referrerRewardBuyForBucketAfter.BuyerTokensExited |> should equal BigInteger.Zero

        let referralBucketAfter = bucketSale.QueryObj<BucketsOutputDTO> "buckets" [| bucketToEnter + BigInteger.One |]
        referralBucketAfter.TotalValueEntered |> should equal (referralBucketBefore.TotalValueEntered)

        
let exitBucket buyer bucketEntered valueEntered =
    let buyerBalanceBefore = FRY.Query "balanceOf" [| buyer |]
    let bucketSaleBalanceBefore = FRY.Query "balanceOf" [| bucketSale.Address |]
    let totalTokensExitedBefore = bucketSale.Query "totalExitedTokens" [||]

    let exitBucketReceipt = bucketSale.ExecuteFunction "exit" [| bucketEntered; buyer |] 
    // from which account does this happen?
    exitBucketReceipt |> shouldSucceed

    let bucket = bucketSale.QueryObj<BucketsOutputDTO> "buckets" [| bucketEntered |]
    let amountToExit = 
        (bucketSupply * (BigInteger 100000UL) * valueEntered) / (bucket.TotalValueEntered * (BigInteger 100000UL))

    let exitEvent = exitBucketReceipt |> decodeFirstEvent<ExitedEventDTO>
    exitEvent.BucketId |> should equal bucketEntered
    exitEvent.Buyer |> shouldEqualIgnoringCase buyer
    exitEvent.TokensExited |> should equal amountToExit

    let buy = bucketSale.QueryObj<BuysOutputDTO> "buys" [| bucketEntered; buyer |]
    buy.BuyerTokensExited |> should equal amountToExit
    buy.ValueEntered |> should equal valueEntered

    let totalTokensExitedAfter = bucketSale.Query "totalExitedTokens" [||]
    totalTokensExitedAfter |> should equal (totalTokensExitedBefore + amountToExit) 
    
    let buyerBalanceAfter = FRY.Query "balanceOf" [| buyer |]
    buyerBalanceAfter |> should equal (buyerBalanceBefore + amountToExit)

    let bucketSaleBalanceAfter = FRY.Query "balanceOf" [| bucketSale.Address |]
    bucketSaleBalanceAfter |> should equal (bucketSaleBalanceBefore - amountToExit)
