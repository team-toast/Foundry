module EnterTests

open FsUnit.Xunit
open Xunit
open TestBase
open System.Numerics
open Constants
open System
open BucketSaleTestBase
open Nethereum.RPC.Eth.DTOs
open Foundry.Contracts.Debug.ContractDefinition
open Nethereum.Hex.HexConvertors.Extensions


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

    let balanceAfter = ethConn.Web3.Eth.GetBalance.SendRequestAsync(zeroAddress) |> runNow // TODO: remove zeroAddress
    balanceAfter.Value |> should greaterThan (bigInt 1UL)


[<Specification("BucketSale", "constructor", 1)>]
[<Fact>]
let ``B_C000 - Can construct the contract``() =
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
    contract.Query "tokenOnSale" [||] |> shouldEqualIgnoringCase tokenOnSale // TODO: this should fail
    contract.Query "tokenSoldFor" [||] |> shouldEqualIgnoringCase tokenSoldFor


[<Specification("BucketSale", "enter", 1)>]
[<Specification("BucketSale", "enter", 5)>]
[<Fact>]
let ``B_EN001|B_EN005 - Cannot enter a past bucket``() =
    let currentBucket = bucketSale.Query "currentBucket" [||] |> uint64
    let bucketInPast = currentBucket - 1UL
    let receipt = bucketSale.ExecuteFunctionFrom "enter" [| ethConn.Account.Address; bucketInPast; 1UL; zeroAddress |] debug
    let forwardEvent = debug.DecodeForwardedEvents receipt |> Seq.head
    forwardEvent |> shouldRevertWithMessage "cannot enter past buckets"


[<Specification("BucketSale", "enter", 2)>]
[<Fact>]
let ``B_EN002 - Cannot enter a bucket beyond the designated bucket count (no referrer)``() =
    addFryMinter bucketSale.Address
    let bucketCount = bucketSale.Query "bucketCount" [||] // will be one greater than what can be correctly entered
    let receipt = bucketSale.ExecuteFunctionFrom "enter" [| ethConn.Account.Address; bucketCount; 1UL; zeroAddress |] debug
    let forwardEvent = debug.DecodeForwardedEvents receipt |> Seq.head
    forwardEvent |> shouldRevertWithMessage "invalid bucket id--past end of sale"


[<Specification("BucketSale", "enter", 3)>]
[<Fact>]
let ``B_EN003 - Cannot enter a bucket if payment reverts (with no referrer)``() =
    addFryMinter bucketSale.Address
    seedWithDAI debug.ContractPlug.Address (BigInteger(10UL))
    let currentBucket = bucketSale.Query "currentBucket" [||]
    // TODO: Verify and make clear this is failing because of a lack of Approve
    let receipt = bucketSale.ExecuteFunctionFrom "enter" [| ethConn.Account.Address; currentBucket; 1UL; zeroAddress |] debug
    let forwardEvent = debug.DecodeForwardedEvents receipt |> Seq.head
    forwardEvent |> shouldRevertWithUnknownMessage


[<Specification("BucketSale", "enter", 4)>]
[<Fact>]
let ``B_EN004 - Can enter a bucket with no referrer``() =
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
            enterBucket // TODO: Make clear what this asserts, or maybe rename to enterBucketShouldSucceed??
                sender
                buyer
                bucketToEnter
                valueToEnter
                referrer)


[<Specification("BucketSale", "enter", 6)>]
[<Fact>]
let ``B_EN006 - Cannot enter a bucket beyond the designated bucket count - 1 (because of referrer)``() =
    let valueToEnter = BigInteger(10L)

    addFryMinter bucketSale.Address
    seedWithDAI debug.ContractPlug.Address valueToEnter

    let approveDaiReceipt =  DAI.ExecuteFunctionFrom "approve" [| bucketSale.Address; valueToEnter |] debug
    approveDaiReceipt |> shouldSucceed

    let bucketCount = bucketSale.Query "bucketCount" [||] // will be one greater than what can be correctly entered
    let receipt =
        bucketSale.ExecuteFunctionFrom
            "enter"
            [| ethConn.Account.Address; bucketCount - 1; 1UL; debug.ContractPlug.Address |]
            debug

    let forwardEvent = debug.DecodeForwardedEvents receipt |> Seq.head
    forwardEvent |> shouldRevertWithMessage "invalid bucket id--past end of sale"


[<Specification("BucketSale", "enter", 7)>]
[<Fact>]
let ``B_EN007 - Cannot enter a bucket if payment reverts (with referrer)``() =
    addFryMinter bucketSale.Address
    seedWithDAI debug.ContractPlug.Address (BigInteger(10UL)) // seed but do not approve, which will make the enter revert
    let currentBucket = bucketSale.Query "currentBucket" [||]
    let receipt = bucketSale.ExecuteFunctionFrom "enter" [| ethConn.Account.Address; currentBucket; 1UL; debug.ContractPlug.Address |] debug
    let forwardEvent = debug.DecodeForwardedEvents receipt |> Seq.head
    forwardEvent |> shouldRevertWithUnknownMessage


[<Specification("BucketSale", "enter", 8)>]
[<Fact>]
let ``B_EN008 - Can enter a bucket with a referrer``() =
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
let ``B_EX001 - Cannot exit a bucket that is not yet concluded``() =
    let currentBucket = bucketSale.Query "currentBucket" [||]
    let firstReceipt = bucketSale.ExecuteFunctionFrom "exit" [| currentBucket; EthAddress.Zero |] debug

    let firstForwardEvent = decodeFirstEvent<ForwardedEventDTO> firstReceipt
    firstForwardEvent.MsgSender |> shouldEqualIgnoringCase ethConn.Account.Address
    firstForwardEvent.Success |> should equal false // TODO: Do we need these extra lines?
    firstForwardEvent.To |> should equal bucketSale.Address
    firstForwardEvent.Wei |> should equal BigInteger.Zero
    firstForwardEvent |> shouldRevertWithMessage "can only exit from concluded buckets"

    let laterBucket = rnd.Next((currentBucket + BigInteger.One) |> int32, (bucketCount - BigInteger 1UL) |> int32)
    let secondReceipt = bucketSale.ExecuteFunctionFrom "exit" [| laterBucket; EthAddress.Zero |] debug

    let secondForwardEvent = decodeFirstEvent<ForwardedEventDTO> secondReceipt
    secondForwardEvent.MsgSender |> shouldEqualIgnoringCase ethConn.Account.Address
    secondForwardEvent.Success |> should equal false
    secondForwardEvent.To |> should equal bucketSale.Address
    secondForwardEvent.Wei |> should equal BigInteger.Zero
    secondForwardEvent |> shouldRevertWithMessage "can only exit from concluded buckets"


[<Specification("BucketSale", "exit", 2)>]
[<Fact>]
let ``B_EX002 - Cannot exit a bucket you did not enter``() =
    let currentBucket = bucketSale.Query "currentBucket" [||]
    let randomAddress = makeAccount().Address
    let firstReceipt = bucketSale.ExecuteFunctionFrom "exit" [| currentBucket - BigInteger.One; randomAddress |] debug

    let firstForwardEvent = decodeFirstEvent<ForwardedEventDTO> firstReceipt
    firstForwardEvent.MsgSender |> shouldEqualIgnoringCase ethConn.Account.Address
    firstForwardEvent.Success |> should equal false
    firstForwardEvent.To |> should equal bucketSale.Address
    firstForwardEvent.Wei |> should equal BigInteger.Zero
    firstForwardEvent |> shouldRevertWithMessage "can't exit if you didn't enter"


[<Specification("BucketSale", "exit", 3)>]
[<Fact>]
let ``B_EX003 - Cannot exit a buy you have already exited``() =
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

    ethConn.TimeTravel bucketPeriod // TODO: Check for other odd usages of period |> timeTravel

    let firstReceipt = bucketSale.ExecuteFunctionFrom "exit" [| currentBucket; buyer |] debug
    let firstForwardEvent = decodeFirstEvent<ForwardedEventDTO> firstReceipt
    firstForwardEvent.MsgSender |> shouldEqualIgnoringCase ethConn.Account.Address
    firstForwardEvent.Success |> should equal true
    firstForwardEvent.To |> should equal bucketSale.Address
    firstForwardEvent.Wei |> should equal BigInteger.Zero

    let secondReceipt = bucketSale.ExecuteFunctionFrom "exit" [| currentBucket; buyer |] debug
    let secondForwardEvent = decodeFirstEvent<ForwardedEventDTO> secondReceipt
    secondForwardEvent.MsgSender |> shouldEqualIgnoringCase ethConn.Account.Address
    secondForwardEvent.Success |> should equal false
    secondForwardEvent.To |> should equal bucketSale.Address
    secondForwardEvent.Wei |> should equal BigInteger.Zero
    secondForwardEvent |> shouldRevertWithMessage "already exited"


[<Specification("BucketSale", "exit", 4)>]
[<Fact>]
let ``B_EX004 - Cannot exit a bucket if the token minting fails``() =
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
    
    // Note that we have not added the minter to bucketSale, so this should cause the minting to fail

    let exitReceipt = bucketSale.ExecuteFunctionFrom "exit" [| currentBucket; buyer |] debug
    let exitForwardEvent = decodeFirstEvent<Foundry.Contracts.Debug.ContractDefinition.ForwardedEventDTO> exitReceipt
    exitForwardEvent.MsgSender |> shouldEqualIgnoringCase ethConn.Account.Address
    exitForwardEvent.Success |> should equal false
    exitForwardEvent.To |> should equal bucketSale.Address
    exitForwardEvent.Wei |> should equal BigInteger.Zero
    exitForwardEvent |> shouldRevertWithUnknownMessage // unknown internal revert of the ERC20 minting, error is not necessarily known


[<Specification("BucketSale", "exit", 5)>]
[<Fact>]
let ``B_EX005 - Can exit a valid past bucket that was entered``() =
    addFryMinter bucketSale.Address

    let initialTimeJump = rnd.Next(0, (bucketCount * bucketPeriod / (BigInteger 2)) |> int32) |> uint64
    ethConn.TimeTravel initialTimeJump

    let currentBucketBeforeEntering = bucketSale.Query "currentBucket" [||] // `bucketBeforeEntering` is a confusing name to me
    currentBucketBeforeEntering |> should lessThan bucketCount
    let sender = ethConn.Account.Address
    let randomBuyer = makeAccount().Address
    let randomReferrer = makeAccount().Address

    let makeBuy _ =
        let bucketToEnter = 
            rnd.Next(0, bucketCount - currentBucketBeforeEntering - BigInteger.One |> int32) 
            |> BigInteger 
            |> (+) currentBucketBeforeEntering // TODO: Is there a more straightforward way to do this?
        bucketToEnter |> should greaterThanOrEqualTo currentBucketBeforeEntering
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

    let jumpAfterBuys = (bucketCount - currentBucketBeforeEntering - BigInteger.One) * bucketPeriod |> int64
    ethConn.TimeTravel jumpAfterBuys

    for (buyer, bucketEntered, valueEntered, _) in buysToPerform do
        exitBucket 
            buyer 
            bucketEntered 
            valueEntered


[<Specification("Forwarder", "constructor", 1)>]
[<Fact>]
let ``F_C001 - Can construct a forwarder with an owner``() =
    let abi = Abi("../../../../build/contracts/Forwarder.json")
    let owner = makeAccount()
    
    let deployTxReceipt = ethConn.DeployContractAsync abi [| owner.Address |] |> runNow
    
    deployTxReceipt |> shouldSucceed
    deployTxReceipt.Logs.Count |> should equal 0 
    let forwarder = ContractPlug(ethConn, abi, deployTxReceipt.ContractAddress) 
    forwarder.Query "owner" [| |] |> shouldEqualIgnoringCase owner.Address



[<Specification("Forwarder", "changeOwner", 1)>]
[<Fact>]
let ``F_CO001 - Cannot change the owner if not called by the current owner``() =
    let testTreasury = makeTreasury ethConn.Account.Address

    let newOwner = makeAccount()
    let changeOwnerTx = testTreasury.ExecuteFunctionFrom "changeOwner" [| newOwner.Address |] debug

    changeOwnerTx |> shouldSucceed
    let forwardedEvent = changeOwnerTx |> decodeFirstEvent<ForwardedEventDTO> 
    forwardedEvent.To |> shouldEqualIgnoringCase testTreasury.Address
    forwardedEvent |> shouldRevertWithMessage "only owner"


[<Specification("Forwarder", "changeOwner", 2)>]
[<Fact>]
let ``F_CO002 - Should change the owner if called by the current owner``() =
    let testTreasury = makeTreasury ethConn.Account.Address

    let newOwner = makeAccount()
    let changeOwnerTx = testTreasury.ExecuteFunctionFrom "changeOwner" [| newOwner.Address |] ethConn

    changeOwnerTx |> shouldSucceed
    let ownerChangedEvent = changeOwnerTx |> decodeFirstEvent<Foundry.Contracts.Forwarder.ContractDefinition.OwnerChangedEventDTO> 
    ownerChangedEvent.NewOwner |> shouldEqualIgnoringCase newOwner.Address

    testTreasury.Query "owner" [||] |> shouldEqualIgnoringCase newOwner.Address


[<Specification("Forwarder", "foward", 1)>]
[<Fact>]
let ``F_F001 - Cannot be called by a non-owner``() =
    let forwardTx = treasury.ExecuteFunctionFrom "forward" [| EthAddress.Zero; "".HexToByteArray(); BigInteger 0UL |] debug
    forwardTx |> shouldSucceed
    forwardTx.Logs.Count |> should equal 1
    let forwardEvent = forwardTx |> decodeFirstEvent<Foundry.Contracts.Debug.ContractDefinition.ForwardedEventDTO>
    forwardEvent.MsgSender |> shouldEqualIgnoringCase ethConn.Account.Address
    forwardEvent.Success |> should equal false
    forwardEvent.To |> should equal treasury.Address
    forwardEvent.Wei |> should equal BigInteger.Zero
    forwardEvent |> shouldRevertWithMessage "only owner"


[<Specification("Forwarder", "foward", 2)>]
[<Fact>]
let ``F_F002 - Should succeed when called by a owner and handle a reverting call``() =
    let forwardTx = treasury.ExecuteFunction "forward" [| bucketSale.Address; "".HexToByteArray(); BigInteger 0UL |]
    
    forwardTx |> shouldSucceed
    forwardTx.Logs.Count |> should equal 1
    let forwardEvent = forwardTx |> decodeFirstEvent<Foundry.Contracts.Forwarder.ContractDefinition.ForwardedEventDTO>
    forwardEvent.Success |> should equal false
    forwardEvent.To |> should equal bucketSale.Address
    forwardEvent.Wei |> should equal BigInteger.Zero


[<Specification("Forwarder", "foward", 3)>]
[<Fact>]
let ``F_F003A - Should succeed when called by a owner when making a successful call``() =
    seedWithDAI treasury.Address (BigInteger 100UL)
    let recipient = makeAccount()
    let treasuryBalanceBefore = DAI.Query "balanceOf" [| treasury.Address |]
    let recipientBalanceBefore = DAI.Query "balanceOf" [| recipient.Address |]
    let amount = rnd.Next(0,100) |> BigInteger
    let sendDaiData = DAI.FunctionData "transfer" [| recipient.Address; amount |]
    
    let forwardTx = treasury.ExecuteFunction "forward" [| DAI.Address; sendDaiData.HexToByteArray(); BigInteger 0UL |]
    
    forwardTx |> shouldSucceed
    forwardTx.Logs.Count |> should greaterThan 1
    let forwardEvent = forwardTx |> decodeFirstEvent<Foundry.Contracts.Forwarder.ContractDefinition.ForwardedEventDTO>
    forwardEvent.Success |> should equal true
    forwardEvent.To |> should equal DAI.Address
    forwardEvent.Wei |> should equal BigInteger.Zero

    DAI.Query "balanceOf" [| treasury.Address |] |> should equal (treasuryBalanceBefore - amount)
    DAI.Query "balanceOf" [| recipient.Address |] |> should equal (recipientBalanceBefore + amount)

[<Specification("Forwarder", "foward", 3)>]
[<Fact>]
let ``F_F003B - Should succeed when called by a owner and sending eth``() =
    let recipient = makeAccount()
    let amount = rnd.Next(0,100) |> BigInteger
    let seedEthReciept = ethConn.SendEther treasury.Address amount
    seedEthReciept |> shouldSucceed
    let treasuryBalanceBefore = ethConn.GetEtherBalance treasury.Address
    let recipientBalanceBefore = ethConn.GetEtherBalance recipient.Address 
    
    let forwardTx = treasury.ExecuteFunction "forward" [| recipient.Address; "".HexToByteArray(); amount |]
    
    forwardTx |> shouldSucceed
    forwardTx.Logs.Count |> should greaterThan 0
    let forwardEvent = forwardTx |> decodeFirstEvent<Foundry.Contracts.Forwarder.ContractDefinition.ForwardedEventDTO>
    forwardEvent.Success |> should equal true
    forwardEvent.To |> shouldEqualIgnoringCase recipient.Address
    forwardEvent.Wei |> should equal amount

    ethConn.GetEtherBalance treasury.Address |> should equal (treasuryBalanceBefore - amount)
    ethConn.GetEtherBalance recipient.Address |> should equal (recipientBalanceBefore + amount)

[<Specification("Forwarder", "fallback", 1)>]
[<Fact>]
let ``F_FB001 - Should be able to receive eth``() =
    let testTreasury = makeTreasury ethConn.Account.Address
    let balanceBefore = ethConn.GetEtherBalance testTreasury.Address
    let amount = rnd.Next(0,100) |> BigInteger
    
    let sendEtherTx = ethConn.SendEther testTreasury.Address amount

    sendEtherTx |> shouldSucceed 
    sendEtherTx.Logs |> should be Empty
    ethConn.GetEtherBalance testTreasury.Address |> should equal (balanceBefore + amount)


