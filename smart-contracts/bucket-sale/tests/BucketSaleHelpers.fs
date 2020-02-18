module bucketSaleHelpers

open BucketSaleTestBase


let enterBucket sender buyer bucketToEnter valueToEnter referrer =
    let approveDaiTxReceipt = DAI.ExecuteFunction "approve" [| bucketSale.Address; valueToEnter |]
    approveDaiTxReceipt |> shouldSucceed

    let currentBucket = bucketSale.Query "currentBucket" [||]
    let referredTotalBefore = bucketSale.Query "referredTotal" [| referrer |]
    let referrerRewardPercBefore = bucketSale.Query "referrerReferralRewardPerc" [| referrer |]
    let calculatedReferrerRewardPercBefore = referrerReward referredTotalBefore
    referrerRewardPercBefore |> should equal calculatedReferrerRewardPercBefore
    let senderDaiBalanceBefore = DAI.Query "balanceOf" [| sender |]
    let bucketDaiBalanceBefore = DAI.Query "balanceOf" [| bucketSale.Address |]
    let buyForBucketBefore = bucketSale.QueryObj<BuysOutputDTO> "buys" [| bucketToEnter; buyer |]
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
    referredTotalAfter |> should equal (referredTotalBefore + valueToEnter)
    let calculatedReferrerRewardPercAfter = referrerReward referredTotalAfter
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
        enteredEvent.Referrer |> shouldEqualIgnoringCase referrer
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
    let bucketDaiBalanceAfter = DAI.Query "balanceOf" [| bucketSale.Address |]
    bucketDaiBalanceAfter |> should equal (bucketDaiBalanceBefore + valueToEnter)

    let buyForBucketAfter = bucketSale.QueryObj<BuysOutputDTO> "buys" [| bucketToEnter; buyer |]
    buyForBucketAfter.ValueEntered |> should equal (buyForBucketBefore.ValueEntered + valueToEnter)
    buyForBucketAfter.BuyerTokensExited |> should equal BigInteger.Zero

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
    let totalTokensExitedBefore = bucketSale.Query "totalTokensExited" [||]

    let exitBucketReceipt = bucketSale.ExecuteFunction "exit" [| bucketEntered; buyer |] 
    exitBucketReceipt |> shouldSucceed

    let bucket = bucketSale.QueryObj<BucketsOutputDTO> "buckets" [| bucketEntered |]
    let amountToExit = 
        (BigInteger 100000UL) * valueEntered / bucket.TotalValueEntered

    let exitEvent = exitBucketReceipt |> decodeFirstEvent<ExitedEventDTO>
    exitEvent.BucketId |> should equal bucketEntered
    exitEvent.Buyer |> should equal buyer
    exitEvent.TokensExited |> should equal amountToExit

    let buy = bucketSale.QueryObj<BuysOutputDTO> "buys" [| bucketEntered; buyer |]
    buy.BuyerTokensExited |> should equal amountToExit
    buy.ValueEntered |> should equal valueEntered

    let totalTokensExitedAfter = bucketSale.Query "totalTokensExited" [||]
    totalTokensExitedAfter |> should equal (totalTokensExitedBefore + amountToExit) 
    
    let buyerBalanceAfter = FRY.Query "balanceOf" [| buyer |]
    buyerBalanceAfter |> should equal (buyerBalanceBefore + amountToExit)

    let bucketSaleBalanceAfter = FRY.Query "balanceOf" [| bucketSale.Address |]
    bucketSaleBalanceAfter |> should equal (bucketSaleBalanceBefore - amountToExit)
