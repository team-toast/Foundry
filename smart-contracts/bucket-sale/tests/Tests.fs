module EnterTests

open FsUnit.Xunit
open Xunit
open TestBase
open System.Numerics
open Constants
open System
open BucketSaleTestBase
open Nethereum.RPC.Eth.DTOs


[<Specification("BucketSale", "misc", 0)>]
[<Fact>]
let ``M000 - Can send eth``() =
    let balance = ethConn.Web3.Eth.GetBalance.SendRequestAsync(ethConn.Account.Address) |> runNow
    balance.Value |> should greaterThan (bigInt 0UL)

    let transactionInput =
        TransactionInput
            ("", zeroAddress, ethConn.Account.Address, hexBigInt 4000000UL, hexBigInt 1000000000UL, hexBigInt 1UL)

    let sendEthTxReceipt =
        ethConn.Web3.Eth.TransactionManager.SendTransactionAndWaitForReceiptAsync(transactionInput, null) |> runNow

    sendEthTxReceipt |> shouldSucceed

    let balanceAfter = ethConn.Web3.Eth.GetBalance.SendRequestAsync(zeroAddress) |> runNow
    balanceAfter.Value |> should greaterThan (bigInt 1UL)


[<Specification("BucketSale", "constructor", 1)>]
[<Fact>]
let ``C000 - Can construct the contract``() =
    let abi = Abi("../../../../build/contracts/BucketSale.json")
    let deployTxReceipt =
        ethConn.DeployContractAsync abi
            [| treasury.Address; startOfSale; bucketPeriod; bucketSupply; bucketCount; zeroAddress; zeroAddress |]
        |> runNow

    deployTxReceipt |> shouldSucceed

    // Assert
    let contract = ContractPlug(ethConn, abi, deployTxReceipt.ContractAddress)

    contract.Query "treasury" [||] |> shouldEqualIgnoringCase treasury.Address
    contract.Query "startOfSale" [||] |> should equal startOfSale
    contract.Query "bucketPeriod" [||] |> should equal bucketPeriod
    contract.Query "bucketSupply" [||] |> should equal bucketSupply
    contract.Query "bucketCount" [||] |> should equal bucketCount
    contract.Query "tokenOnSale" [||] |> shouldEqualIgnoringCase tokenOnSale
    contract.Query "tokenSoldFor" [||] |> shouldEqualIgnoringCase tokenSoldFor


[<Specification("BucketSale", "enter", 1)>]
[<Specification("BucketSale", "enter", 5)>]
[<Fact>]
let ``E001|E005 - Cannot enter a past bucket``() =
    let currentBucket = bucketSale.Query "currentBucket" [||] |> uint64
    let incorrectBucket = currentBucket - 1UL
    let receipt = bucketSale.ExecuteFunctionFrom "enter" [| ethConn.Account.Address; incorrectBucket; 1UL; zeroAddress |] forwarder
    let forwardEvent = forwarder.DecodeForwardedEvents receipt |> Seq.head
    forwardEvent |> shouldRevertWithMessage "cannot enter past buckets"


[<Specification("BucketSale", "enter", 2)>]
[<Fact>]
let ``E002 - Cannot enter a bucket beyond the designated bucket count (no referrer)``() =
    addFryMinter bucketSale.Address
    let bucketCount = bucketSale.Query "bucketCount" [||] // will be one greater than what can be correctly entered
    let receipt = bucketSale.ExecuteFunctionFrom "enter" [| ethConn.Account.Address; bucketCount; 1UL; zeroAddress |] forwarder
    let forwardEvent = forwarder.DecodeForwardedEvents receipt |> Seq.head
    forwardEvent |> shouldRevertWithMessage "invalid bucket id--past end of sale"


[<Specification("BucketSale", "enter", 3)>]
[<Fact>]
let ``E003 - Cannot enter a bucket if payment reverts (with no referrer)``() =
    addFryMinter bucketSale.Address
    seedWithDAI forwarder.ContractPlug.Address (BigInteger(10UL))
    let currentBucket = bucketSale.Query "currentBucket" [||]
    let receipt = bucketSale.ExecuteFunctionFrom "enter" [| ethConn.Account.Address; currentBucket; 1UL; zeroAddress |] forwarder
    let forwardEvent = forwarder.DecodeForwardedEvents receipt |> Seq.head
    forwardEvent |> shouldRevertWithUnknownMessage


[<Specification("BucketSale", "enter", 4)>]
[<Fact>]
let ``E004 - Can enter a bucket with no referrer``() =
    // arrange
    addFryMinter bucketSale.Address

    let currentBucket = bucketSale.Query "currentBucket" [||]

    let valueToEnter = BigInteger 10UL
    let referrer = zeroAddress
    let buyer = ethConn.Account.Address
    let sender = ethConn.Account.Address

    let bucketsToEnter =
        rndRange (currentBucket |> int) (bucketCount - BigInteger.One |> int)
        |> Seq.take 5
        |> Seq.toArray
        |> Array.append [| currentBucket; bucketCount - BigInteger.One |]

    Array.ForEach(
        bucketsToEnter,
        fun bucketToEnter ->
            enterBucket
                sender
                buyer
                bucketToEnter
                valueToEnter
                referrer)


[<Specification("BucketSale", "enter", 6)>]
[<Fact>]
let ``E006 - Cannot enter a bucket beyond the designated bucket count - 1 (because of referrer)``() =
    let valueToEnter = BigInteger(10L)

    addFryMinter bucketSale.Address
    seedWithDAI forwarder.ContractPlug.Address valueToEnter

    let approveDaiReceipt =  DAI.ExecuteFunctionFrom "approve" [| bucketSale.Address; valueToEnter |] forwarder
    approveDaiReceipt |> shouldSucceed

    let bucketCount = bucketSale.Query "bucketCount" [||] // will be one greater than what can be correctly entered
    let receipt =
        bucketSale.ExecuteFunctionFrom
            "enter"
            [| ethConn.Account.Address; bucketCount - 1; 1UL; forwarder.ContractPlug.Address |]
            forwarder

    let forwardEvent = forwarder.DecodeForwardedEvents receipt |> Seq.head
    forwardEvent |> shouldRevertWithMessage "invalid bucket id--past end of sale"


[<Specification("BucketSale", "enter", 7)>]
[<Fact>]
let ``E007 - Cannot enter a bucket if payment reverts (with referrer)``() =
    addFryMinter bucketSale.Address
    seedWithDAI forwarder.ContractPlug.Address (BigInteger(10UL)) // seed but do not approve, which will make the enter revert
    let currentBucket = bucketSale.Query "currentBucket" [||]
    let receipt = bucketSale.ExecuteFunctionFrom "enter" [| ethConn.Account.Address; currentBucket; 1UL; forwarder.ContractPlug.Address |] forwarder
    let forwardEvent = forwarder.DecodeForwardedEvents receipt |> Seq.head
    forwardEvent |> shouldRevertWithUnknownMessage


[<Specification("BucketSale", "enter", 8)>]
[<Fact>]
let ``E008 - Can enter a bucket with a referrer``() =
    // arrange
    addFryMinter bucketSale.Address

    let currentBucket = bucketSale.Query "currentBucket" [||]

    let valueToEnter = BigInteger 10UL
    let buyer = ethConn.Account.Address
    let sender = ethConn.Account.Address
    let randomReferrer = makeAccount().Address

    let bucketsToEnter =
        rndRange (currentBucket |> int) (bucketCount - BigInteger 2UL  |> int)
        |> Seq.take 5
        |> Seq.toArray
        |> Array.append [| currentBucket; bucketCount - BigInteger 2UL |]

    Array.ForEach(
        bucketsToEnter,
        fun bucketToEnter ->
            enterBucket
                sender
                buyer
                bucketToEnter
                valueToEnter
                randomReferrer)


[<Specification("BucketSale", "exit", 1)>]
[<Fact>]
let ``EX001 - Cannot exit a bucket that is not yet concluded``() =
    let currentBucket = bucketSale.Query "currentBucket" [||]
    let firstReceipt = bucketSale.ExecuteFunctionFrom "exit" [| currentBucket; EthAddress.Zero |] forwarder

    let firstForwardEvent = decodeFirstEvent<Foundry.Contracts.Forwarder.ContractDefinition.ForwardedEventDTO> firstReceipt
    firstForwardEvent.MsgSender |> shouldEqualIgnoringCase ethConn.Account.Address
    firstForwardEvent.Success |> should equal false
    firstForwardEvent.To |> should equal bucketSale.Address
    firstForwardEvent.Wei |> should equal BigInteger.Zero
    firstForwardEvent |> shouldRevertWithMessage "can only exit from concluded buckets"

    let laterBucket = rnd.Next((currentBucket + BigInteger.One) |> int32, (bucketCount - BigInteger 1UL) |> int32)
    let secondReceipt = bucketSale.ExecuteFunctionFrom "exit" [| laterBucket; EthAddress.Zero |] forwarder

    let secondForwardEvent = decodeFirstEvent<Foundry.Contracts.Forwarder.ContractDefinition.ForwardedEventDTO> secondReceipt
    secondForwardEvent.MsgSender |> shouldEqualIgnoringCase ethConn.Account.Address
    secondForwardEvent.Success |> should equal false
    secondForwardEvent.To |> should equal bucketSale.Address
    secondForwardEvent.Wei |> should equal BigInteger.Zero
    secondForwardEvent |> shouldRevertWithMessage "can only exit from concluded buckets"


[<Specification("BucketSale", "exit", 2)>]
[<Fact>]
let ``EX002 - Cannot exit a bucket you did not enter``() =
    let currentBucket = bucketSale.Query "currentBucket" [||]
    let randomAddress = makeAccount().Address
    let firstReceipt = bucketSale.ExecuteFunctionFrom "exit" [| currentBucket - BigInteger.One; randomAddress |] forwarder

    let firstForwardEvent = decodeFirstEvent<Foundry.Contracts.Forwarder.ContractDefinition.ForwardedEventDTO> firstReceipt
    firstForwardEvent.MsgSender |> shouldEqualIgnoringCase ethConn.Account.Address
    firstForwardEvent.Success |> should equal false
    firstForwardEvent.To |> should equal bucketSale.Address
    firstForwardEvent.Wei |> should equal BigInteger.Zero
    firstForwardEvent |> shouldRevertWithMessage "can't exit if you didn't enter"


[<Specification("BucketSale", "exit", 3)>]
[<Fact>]
let ``EX003 - Cannot exit a buy you have already exited``() =
    addFryMinter bucketSale.Address

    let currentBucket = bucketSale.Query "currentBucket" [||]
    let valueToEnter = BigInteger 10UL
    let buyer = ethConn.Account.Address
    let sender = ethConn.Account.Address
    let randomReferrer = makeAccount().Address

    enterBucket
        sender
        buyer
        currentBucket
        valueToEnter
        randomReferrer

    bucketPeriod |> ethConn.TimeTravel 

    let firstReceipt = bucketSale.ExecuteFunctionFrom "exit" [| currentBucket; buyer |] forwarder
    let firstForwardEvent = decodeFirstEvent<Foundry.Contracts.Forwarder.ContractDefinition.ForwardedEventDTO> firstReceipt
    firstForwardEvent.MsgSender |> shouldEqualIgnoringCase ethConn.Account.Address
    firstForwardEvent.Success |> should equal true
    firstForwardEvent.To |> should equal bucketSale.Address
    firstForwardEvent.Wei |> should equal BigInteger.Zero

    let secondReceipt = bucketSale.ExecuteFunctionFrom "exit" [| currentBucket; buyer |] forwarder
    let secondForwardEvent = decodeFirstEvent<Foundry.Contracts.Forwarder.ContractDefinition.ForwardedEventDTO> secondReceipt
    secondForwardEvent.MsgSender |> shouldEqualIgnoringCase ethConn.Account.Address
    secondForwardEvent.Success |> should equal false
    secondForwardEvent.To |> should equal bucketSale.Address
    secondForwardEvent.Wei |> should equal BigInteger.Zero
    secondForwardEvent |> shouldRevertWithMessage "already exited"


[<Specification("BucketSale", "exit", 4)>]
[<Fact>]
let ``EX004 - Cannot exit a bucket if the token minting fails``() =
    let currentBucket = bucketSale.Query "currentBucket" [||]
    let valueToEnter = BigInteger 10UL
    let buyer = ethConn.Account.Address
    let sender = ethConn.Account.Address
    let randomReferrer = makeAccount().Address

    enterBucket
        sender
        buyer
        currentBucket
        valueToEnter
        randomReferrer

    bucketPeriod |> ethConn.TimeTravel 
    
    let exitReceipt = bucketSale.ExecuteFunctionFrom "exit" [| currentBucket; buyer |] forwarder
    let exitForwardEvent = decodeFirstEvent<Foundry.Contracts.Forwarder.ContractDefinition.ForwardedEventDTO> exitReceipt
    exitForwardEvent.MsgSender |> shouldEqualIgnoringCase ethConn.Account.Address
    exitForwardEvent.Success |> should equal false
    exitForwardEvent.To |> should equal bucketSale.Address
    exitForwardEvent.Wei |> should equal BigInteger.Zero
    exitForwardEvent |> shouldRevertWithUnknownMessage //unknown internal revert of the ERC20, error is not necessarily known


[<Specification("BucketSale", "exit", 5)>]
[<Fact>]
let ``EX005 - Can exit a valid past bucket that was entered``() =
    addFryMinter bucketSale.Address

    let initialTimeJump = rnd.Next(0, (bucketCount * bucketPeriod / (BigInteger 2)) |> int32) |> uint64
    initialTimeJump |> ethConn.TimeTravel 

    let bucketBeforeEntering = bucketSale.Query "currentBucket" [||]
    bucketBeforeEntering |> should lessThan bucketCount
    let sender = ethConn.Account.Address
    let randomBuyer = makeAccount().Address
    let randomReferrer = makeAccount().Address

    let makeBuy _ =
        let bucketToEnter = 
            rnd.Next(0, bucketCount - bucketBeforeEntering - BigInteger.One |> int32) 
            |> BigInteger 
            |> (+) bucketBeforeEntering
        bucketToEnter |> should greaterThanOrEqualTo bucketBeforeEntering
        bucketToEnter |> should lessThanOrEqualTo (bucketCount - BigInteger.One) 

        randomBuyer,
        bucketToEnter, 
        rnd.Next(1, 100) |> BigInteger,
        randomReferrer
        
    let numberOfBuysToPerform = rnd.Next(5,10)
    let buysToPerform = 
        {1 |> int32 .. numberOfBuysToPerform}
        |> Seq.map makeBuy 
        |> Seq.toArray

    buysToPerform |> Seq.length |> should greaterThanOrEqualTo 5

    for (buyer, bucketToEnter, valueToEnter, referrer) in buysToPerform do
        enterBucket
            sender
            buyer
            bucketToEnter
            valueToEnter
            referrer 

    let jumpAfterBuys = (bucketCount - bucketBeforeEntering - BigInteger.One) * bucketPeriod |> int64
    jumpAfterBuys |> ethConn.TimeTravel

    for (buyer, bucketEntered, valueEntered, _) in buysToPerform do
        exitBucket 
            buyer 
            bucketEntered 
            valueEntered
