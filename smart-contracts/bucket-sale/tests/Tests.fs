module EnterTests

open FsUnit.Xunit
open Xunit
open TestBase
open System.Numerics
open Nethereum.Hex.HexConvertors.Extensions
open Constants
open System
open DAIHard.Contracts.BucketSale.ContractDefinition
open BucketSaleTestBase
open Nethereum.Web3.Accounts
open Nethereum.RPC.Eth.DTOs
open Nethereum.Contracts
open System.Text
open System.Linq

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
            [| ethConn.Account.Address; startOfSale; bucketPeriod; bucketSupply; bucketCount; zeroAddress; zeroAddress |]
        |> runNow

    deployTxReceipt |> shouldSucceed

    // Assert
    let contract = ContractPlug(ethConn, abi, deployTxReceipt.ContractAddress)

    contract.Query "owner" [||] |> shouldEqualIgnoringCase ethConn.Account.Address
    contract.Query "startOfSale" [||] |> should equal startOfSale
    contract.Query "bucketPeriod" [||] |> should equal bucketPeriod
    contract.Query "bucketSupply" [||] |> should equal bucketSupply
    contract.Query "bucketCount" [||] |> should equal bucketCount
    contract.Query "tokenOnSale" [||] |> shouldEqualIgnoringCase tokenOnSale
    contract.Query "tokenSoldFor" [||] |> shouldEqualIgnoringCase tokenSoldFor

[<Specification("BucketSale", "enter", 1)>]
[<Fact>]
let ``E001 - Cannot enter bucket sale without putting some money down``() =
    let currentBucket = bucketSale.Query "currentBucket" [||]
    let receipt = bucketSale.ExecuteFunctionFrom "enter"  [| ethConn.Account.Address; currentBucket; 0UL; zeroAddress |] forwarder
    let forwardEvent = forwarder.DecodeForwardedEvents receipt |> Seq.head
    forwardEvent |> shouldRevertWithMessage "can't buy nothing"


[<Specification("BucketSale", "enter", 2)>]
[<Fact>]
let ``E002 - Cannot enter bucket sale if there are not enough tokens to payout``() =
    let currentBucket = bucketSale.Query "currentBucket" [||]

    let balanceBeforeReduction = FRY.Query "balanceOf" [| bucketSale.Address |]
    let moveFryData = FRY.FunctionData "transfer" [| zeroAddress; balanceBeforeReduction |]
    let moveFryForwardData =
        bucketSale.FunctionData "forward"
            [| FRY.Address
               moveFryData.HexToByteArray()
               BigInteger.Zero |]
    let moveFryTxReceipt =
        moveFryForwardData
        |> (ethConn :> IAsyncTxSender).SendTxAsync bucketSale.Address (BigInteger(0))
        |> runNow
    moveFryTxReceipt |> shouldSucceed

    let bucketSaleBalanceBeforeEntry = FRY.Query "balanceOf" [| bucketSale.Address |]
    bucketSaleBalanceBeforeEntry |> should equal BigInteger.Zero
    bucketSaleBalanceBeforeEntry |> should lessThan (bucketCount * bucketSupply)
    let receipt = bucketSale.ExecuteFunctionFrom "enter" [| ethConn.Account.Address; currentBucket; 1UL; zeroAddress |] forwarder
    let forwardEvent = forwarder.DecodeForwardedEvents receipt |> Seq.head
    forwardEvent |> shouldRevertWithMessage "insufficient tokens to sell"


[<Specification("BucketSale", "enter", 3)>]
[<Specification("BucketSale", "enter", 7)>]
[<Fact>]
let ``E003|E007 - Cannot enter a past bucket``() =
    let currentBucket = bucketSale.Query "currentBucket" [||] |> uint64
    let incorrectBucket = currentBucket - 1UL
    let receipt = bucketSale.ExecuteFunctionFrom "enter" [| ethConn.Account.Address; incorrectBucket; 1UL; zeroAddress |] forwarder
    let forwardEvent = forwarder.DecodeForwardedEvents receipt |> Seq.head
    forwardEvent |> shouldRevertWithMessage "cannot enter past buckets"


[<Specification("BucketSale", "enter", 4)>]
[<Fact>]
let ``E004 - Cannot enter a bucket beyond the designated bucket count (no referrer)``() =
    seedBucketWithFries()
    let bucketCount = bucketSale.Query "bucketCount" [||] // will be one greater than what can be correctly entered
    let receipt = bucketSale.ExecuteFunctionFrom "enter" [| ethConn.Account.Address; bucketCount; 1UL; zeroAddress |] forwarder
    let forwardEvent = forwarder.DecodeForwardedEvents receipt |> Seq.head
    forwardEvent |> shouldRevertWithMessage "invalid bucket id--past end of sale"


[<Specification("BucketSale", "enter", 5)>]
[<Fact>]
let ``E005 - Cannot enter a bucket if payment reverts (with no referrer)``() =
    seedBucketWithFries()
    seedWithDAI forwarder.ContractPlug.Address (BigInteger(10UL))
    let currentBucket = bucketSale.Query "currentBucket" [||]
    let receipt = bucketSale.ExecuteFunctionFrom "enter" [| ethConn.Account.Address; currentBucket; 1UL; zeroAddress |] forwarder
    let forwardEvent = forwarder.DecodeForwardedEvents receipt |> Seq.head
    forwardEvent |> shouldRevertWithUnknownMessage


[<Specification("BucketSale", "enter", 6)>]
[<Fact>]
let ``E006 - Can enter a bucket with no referrer``() =
    // arrange
    seedBucketWithFries()

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


[<Specification("BucketSale", "enter", 8)>]
[<Fact>]
let ``E008 - Cannot enter a bucket beyond the designated bucket count - 1 (because of referrer)``() =
    let valueToEnter = BigInteger(10L)

    seedBucketWithFries()
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


[<Specification("BucketSale", "enter", 9)>]
[<Fact>]
let ``E009 - Cannot enter a bucket if payment reverts (with referrer)``() =
    seedBucketWithFries()
    seedWithDAI forwarder.ContractPlug.Address (BigInteger(10UL)) // seed but do not approve, which will make the enter revert
    let currentBucket = bucketSale.Query "currentBucket" [||]
    let receipt = bucketSale.ExecuteFunctionFrom "enter" [| ethConn.Account.Address; currentBucket; 1UL; forwarder.ContractPlug.Address |] forwarder
    let forwardEvent = forwarder.DecodeForwardedEvents receipt |> Seq.head
    forwardEvent |> shouldRevertWithUnknownMessage


[<Specification("BucketSale", "enter", 10)>]
[<Fact>]
let ``E010 - Can enter a bucket with a referrer``() =
    // arrange
    seedBucketWithFries()

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

    let firstForwardEvent = decodeFirstEvent<DAIHard.Contracts.Forwarder.ContractDefinition.ForwardedEventDTO> firstReceipt
    firstForwardEvent.MsgSender |> shouldEqualIgnoringCase ethConn.Account.Address
    firstForwardEvent.Success |> should equal false
    firstForwardEvent.To |> should equal bucketSale.Address
    firstForwardEvent.Wei |> should equal BigInteger.Zero
    firstForwardEvent |> shouldRevertWithMessage "can only exit from concluded buckets"

    let laterBucket = rnd.Next((currentBucket + BigInteger.One) |> int32, (bucketCount - BigInteger 1UL) |> int32)
    let secondReceipt = bucketSale.ExecuteFunctionFrom "exit" [| laterBucket; EthAddress.Zero |] forwarder

    let secondForwardEvent = decodeFirstEvent<DAIHard.Contracts.Forwarder.ContractDefinition.ForwardedEventDTO> secondReceipt
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

    let firstForwardEvent = decodeFirstEvent<DAIHard.Contracts.Forwarder.ContractDefinition.ForwardedEventDTO> firstReceipt
    firstForwardEvent.MsgSender |> shouldEqualIgnoringCase ethConn.Account.Address
    firstForwardEvent.Success |> should equal false
    firstForwardEvent.To |> should equal bucketSale.Address
    firstForwardEvent.Wei |> should equal BigInteger.Zero
    firstForwardEvent |> shouldRevertWithMessage "can't take out if you didn't put in"


[<Specification("BucketSale", "exit", 3)>]
[<Fact>]
let ``EX003 - Cannot exit a buy you have already exited``() =
    seedBucketWithFries()

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
    let firstForwardEvent = decodeFirstEvent<DAIHard.Contracts.Forwarder.ContractDefinition.ForwardedEventDTO> firstReceipt
    firstForwardEvent.MsgSender |> shouldEqualIgnoringCase ethConn.Account.Address
    firstForwardEvent.Success |> should equal true
    firstForwardEvent.To |> should equal bucketSale.Address
    firstForwardEvent.Wei |> should equal BigInteger.Zero

    let secondReceipt = bucketSale.ExecuteFunctionFrom "exit" [| currentBucket; buyer |] forwarder
    let secondForwardEvent = decodeFirstEvent<DAIHard.Contracts.Forwarder.ContractDefinition.ForwardedEventDTO> secondReceipt
    secondForwardEvent.MsgSender |> shouldEqualIgnoringCase ethConn.Account.Address
    secondForwardEvent.Success |> should equal false
    secondForwardEvent.To |> should equal bucketSale.Address
    secondForwardEvent.Wei |> should equal BigInteger.Zero
    secondForwardEvent |> shouldRevertWithMessage "already withdrawn"


[<Specification("BucketSale", "exit", 4)>]
[<Fact>]
let ``EX004 - Cannot exit a bucket if the token transfer fails``() =
    seedBucketWithFries()

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
    
    let bucketSaleFryBalance = FRY.Query<BigInteger> "balanceOf" [| bucketSale.Address |] 
    let randomAddress = makeAccount().Address
    
    // move tokens away from bucketSale
    let moveTokensData = FRY.FunctionData "transfer" [| randomAddress; bucketSaleFryBalance |]
    let moveTokensForwardReciept = 
        bucketSale.ExecuteFunction 
            "forward" 
            [|
                FRY.Address
                moveTokensData.HexToByteArray()
                BigInteger.Zero 
            |]
    moveTokensForwardReciept |> shouldSucceed
    let forwardEvent = moveTokensForwardReciept.DecodeAllEvents<ForwardedEventDTO>() |> Seq.head
    forwardEvent.Event.Success |> should equal true
    FRY.Query "balanceOf" [| bucketSale.Address |] |> should lessThan (bucketCount * bucketSupply)

    let exitReceipt = bucketSale.ExecuteFunctionFrom "exit" [| currentBucket; buyer |] forwarder
    let exitForwardEvent = decodeFirstEvent<DAIHard.Contracts.Forwarder.ContractDefinition.ForwardedEventDTO> exitReceipt
    exitForwardEvent.MsgSender |> shouldEqualIgnoringCase ethConn.Account.Address
    exitForwardEvent.Success |> should equal false
    exitForwardEvent.To |> should equal bucketSale.Address
    exitForwardEvent.Wei |> should equal BigInteger.Zero
    exitForwardEvent |> shouldRevertWithUnknownMessage //unknown internal revert of the ERC20, error is not necessarily known


[<Specification("BucketSale", "exit", 5)>]
[<Fact>]
let ``EX005 - Can exit a valid past bucket that was entered``() =
    seedBucketWithFries()

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


[<Specification("BucketSale", "foward", 1)>]
[<Fact>]
let ``F001 - Cannot be called by a non-owner``() =
    seedWithDAI bucketSale.Address (BigInteger 100UL)
    let randomReceiver = makeAccount().Address
    let daiTransferData = DAI.FunctionData "transfer" [| randomReceiver; 100UL |]
    let forwardReceipt = 
        bucketSale.ExecuteFunctionFrom 
            "forward" 
            [| DAI.Address; daiTransferData.HexToByteArray(); BigInteger.Zero |]
            forwarder
    forwardReceipt |> shouldSucceed
    
    let forwarderForwardedEvent = forwardReceipt |> decodeFirstEvent<DAIHard.Contracts.Forwarder.ContractDefinition.ForwardedEventDTO>
    forwarderForwardedEvent |> shouldRevertWithMessage "only owner"

[<Specification("BucketSale", "foward", 2)>]
[<Fact>]
let ``F002 - Should return event indicating revert if the forward fails``() =
    seedWithDAI bucketSale.Address (BigInteger 100UL)
    let randomReceiver = makeAccount().Address
    let daiTransferData = DAI.FunctionData "transfer" [| randomReceiver; 101UL |] // will revert the inner most call
    let forwardReceipt = bucketSale.ExecuteFunction "forward"  [| DAI.Address; daiTransferData.HexToByteArray(); BigInteger.Zero |]
    forwardReceipt |> shouldSucceed
    
    let forwardedEvent = forwardReceipt |> decodeFirstEvent<DAIHard.Contracts.BucketSale.ContractDefinition.ForwardedEventDTO>
    forwardedEvent.Data |> should equal (daiTransferData.HexToByteArray())
    forwardedEvent.Success |> should equal false
    forwardedEvent.To |> should equal DAI.Address

    
[<Specification("BucketSale", "foward", 3)>]
[<Fact>]
let ``F003 - Should be able to forward if sent from owner and call is valid``() =
    // arrange
    seedWithDAI bucketSale.Address (BigInteger 100UL)
    let randomReceiver = makeAccount().Address
    let daiReceiverBalanceBefore = DAI.Query "balanceOf" [| randomReceiver |]
    let bucketSaleBalanceBefore = DAI.Query "balanceOf" [| bucketSale.Address |]
    let daiTransferData = DAI.FunctionData "transfer" [| randomReceiver; 100UL |]
    
    // act
    let forwardReceipt = bucketSale.ExecuteFunction "forward"  [| DAI.Address; daiTransferData.HexToByteArray(); BigInteger.Zero |]
    forwardReceipt |> shouldSucceed
    
    // assert
    let forwardedEvent = forwardReceipt |> decodeFirstEvent<DAIHard.Contracts.BucketSale.ContractDefinition.ForwardedEventDTO>
    forwardedEvent.Data |> should equal (daiTransferData.HexToByteArray())
    forwardedEvent.Success |> should equal true
    forwardedEvent.To |> should equal DAI.Address

    DAI.Query "balanceOf" [| randomReceiver |] |> should equal (daiReceiverBalanceBefore + (BigInteger 100UL))
    DAI.Query "balanceOf" [| bucketSale.Address |] |> should equal (bucketSaleBalanceBefore - (BigInteger 100UL))
