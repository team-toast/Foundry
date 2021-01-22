module Contracts.MultiBucket.Wrappers exposing (..)

import BigInt exposing (BigInt)
import Common.Types exposing (..)
import Config
import Contracts.Generated.ERC20Token as Token
import Contracts.MultiBucket.Generated.MultiBucket as MultiBucketBot
import Eth
import Eth.Types exposing (Address, Call, HttpProvider)
import Helpers.BigInt as BigIntHelpers
import Helpers.Eth as EthHelpers
import Http
import List.Extra
import Task
import TokenValue exposing (TokenValue)


enter :
    Address
    -> Int
    -> TokenValue
    -> Int
    -> Maybe Address
    -> Maybe BigInt
    -> TestMode
    -> Call ()
enter userAddress bucketId amount numberOfBuckets maybeReferrer maybeGasPrice testMode =
    MultiBucketBot.agreeToTermsAndConditionsListedInThisBucketSaleContractAndEnterSaleWithDai
        (Config.multiBucketBotAddress testMode)
        userAddress
        (BigInt.fromInt bucketId)
        (TokenValue.getEvmValue amount)
        (BigInt.fromInt numberOfBuckets)
        (maybeReferrer |> Maybe.withDefault EthHelpers.zeroAddress)
        |> (\call ->
                { call | gasPrice = maybeGasPrice }
           )


approveTransfer :
    TestMode
    -> Call Bool
approveTransfer testMode =
    Token.approve
        (Config.enteringTokenAddress testMode)
        (Config.multiBucketBotAddress testMode)
        EthHelpers.maxUintValue
