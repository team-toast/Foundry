module Contracts.BucketSale.Wrappers exposing (..)

import BigInt exposing (BigInt)
import CommonTypes exposing (..)
import Config
import Contracts.BucketSale.Generated.BucketSale as BucketSaleBindings
import Contracts.BucketSale.Generated.BucketSaleScripts as BucketSaleBindings
import Contracts.Generated.ERC20Token as Token
import Eth
import Eth.Types exposing (Address, Call, HttpProvider)
import Helpers.BigInt as BigIntHelpers
import Helpers.Eth as EthHelpers
import Http
import List.Extra
import Task
import TokenValue exposing (TokenValue)


getSaleStartTimestampCmd :
    TestMode
    -> (Result Http.Error BigInt -> msg)
    -> Cmd msg
getSaleStartTimestampCmd testMode msgConstructor =
    BucketSaleBindings.startOfSale (Config.bucketSaleAddress testMode)
        |> Eth.call (EthHelpers.appHttpProvider testMode)
        |> Task.attempt msgConstructor


getTotalValueEnteredForBucket :
    TestMode
    -> Int
    -> (Result Http.Error TokenValue -> msg)
    -> Cmd msg
getTotalValueEnteredForBucket testMode bucketId msgConstructor =
    BucketSaleBindings.buckets (Config.bucketSaleAddress testMode) (BigInt.fromInt bucketId)
        |> Eth.call (EthHelpers.appHttpProvider testMode)
        |> Task.map TokenValue.tokenValue
        |> Task.attempt msgConstructor


getUserBuyForBucket :
    TestMode
    -> Address
    -> Int
    -> (Result Http.Error BucketSaleBindings.Buy -> msg)
    -> Cmd msg
getUserBuyForBucket testMode userAddress bucketId msgConstructor =
    BucketSaleBindings.buys (Config.bucketSaleAddress testMode) (BigInt.fromInt bucketId) userAddress
        |> Eth.call (EthHelpers.appHttpProvider testMode)
        |> Task.attempt msgConstructor


getTotalExitedTokens :
    TestMode
    -> (Result Http.Error TokenValue -> msg)
    -> Cmd msg
getTotalExitedTokens testMode msgConstructor =
    BucketSaleBindings.totalExitedTokens (Config.bucketSaleAddress testMode)
        |> Eth.call (EthHelpers.appHttpProvider testMode)
        |> Task.map TokenValue.tokenValue
        |> Task.attempt msgConstructor


getSoldTokenBalance :
    TestMode
    -> Address
    -> (Result Http.Error TokenValue -> msg)
    -> Cmd msg
getSoldTokenBalance testMode userAddress msgConstructor =
    Token.balanceOf
        (Config.exitingTokenAddress testMode)
        userAddress
        |> Eth.call (EthHelpers.appHttpProvider testMode)
        |> Task.map TokenValue.tokenValue
        |> Task.attempt msgConstructor


type alias ExitInfo =
    { totalExitable : TokenValue
    , exitableBuckets : List Int
    }


getUserExitInfo :
    TestMode
    -> Address
    -> (Result Http.Error (Maybe ExitInfo) -> msg)
    -> Cmd msg
getUserExitInfo testMode userAddress msgConstructor =
    BucketSaleBindings.getExitInfo
        (Config.bucketSaleScriptsAddress testMode)
        (Config.bucketSaleAddress testMode)
        userAddress
        |> Eth.call (EthHelpers.appHttpProvider testMode)
        |> Task.map queryBigIntListToMaybExitInfo
        |> Task.attempt msgConstructor


type alias StateUpdateInfo =
    { totalTokensExited : TokenValue
    , maybeUserStateInfo : Maybe ( Address, UserStateInfo )
    , bucketInfo : BucketInfo
    }


type alias BucketInfo =
    { bucketId : Int
    , totalTokensEntered : TokenValue
    , userTokensEntered : TokenValue
    , userTokensExited : TokenValue
    }


type alias UserStateInfo =
    { ethBalance : TokenValue
    , enteringTokenBalance : TokenValue
    , enteringTokenAllowance : TokenValue
    , exitingTokenBalance : TokenValue
    , exitInfo : ExitInfo
    }


getStateUpdateInfo :
    TestMode
    -> Maybe Address
    -> Int
    -> SaleType
    -> (Result Http.Error (Maybe StateUpdateInfo) -> msg)
    -> Cmd msg
getStateUpdateInfo testMode maybeUserAddress bucketId saleType msgConstructor =
    BucketSaleBindings.getGeneralInfo
        (Config.bucketSaleScriptsAddress testMode)
        (BigInt.fromInt bucketId)
        (Config.bucketSaleAddress testMode)
        (maybeUserAddress |> Maybe.withDefault EthHelpers.zeroAddress)
        (if saleType == Advanced then
            Config.multiBucketBotAddress testMode

         else
            EthHelpers.zeroAddress
        )
        (Config.enteringTokenAddress testMode)
        |> Eth.call (EthHelpers.appHttpProvider testMode)
        |> Task.map (getGeneralInfoToStateUpdateInfo maybeUserAddress bucketId)
        |> Task.attempt msgConstructor


getGeneralInfoToStateUpdateInfo :
    Maybe Address
    -> Int
    -> BucketSaleBindings.GetGeneralInfo
    -> Maybe StateUpdateInfo
getGeneralInfoToStateUpdateInfo maybeUserAddress bucketId bindingStruct =
    queryBigIntListToMaybExitInfo bindingStruct.exitInfo
        |> Maybe.map
            (\exitInfo ->
                { totalTokensExited = TokenValue.tokenValue bindingStruct.totalExitedTokens
                , maybeUserStateInfo =
                    maybeUserAddress
                        |> Maybe.map
                            (\userAddress ->
                                ( userAddress
                                , { ethBalance = TokenValue.tokenValue bindingStruct.ethBalance
                                  , enteringTokenBalance = TokenValue.tokenValue bindingStruct.tokenSoldForBalance
                                  , enteringTokenAllowance = TokenValue.tokenValue bindingStruct.tokenSoldForAllowance
                                  , exitingTokenBalance = TokenValue.tokenValue bindingStruct.tokenOnSaleBalance
                                  , exitInfo = exitInfo
                                  }
                                )
                            )
                , bucketInfo =
                    { bucketId = bucketId
                    , totalTokensEntered = TokenValue.tokenValue bindingStruct.bucket_totalValueEntered
                    , userTokensEntered = TokenValue.tokenValue bindingStruct.buy_valueEntered
                    , userTokensExited = TokenValue.tokenValue bindingStruct.buy_buyerTokensExited
                    }
                }
            )


approveTransfer :
    TestMode
    -> SaleType
    -> Call Bool
approveTransfer testMode saleType =
    Token.approve
        (Config.enteringTokenAddress testMode)
        (case saleType of
            Standard ->
                Config.bucketSaleAddress testMode

            Advanced ->
                Config.multiBucketBotAddress testMode
        )
        EthHelpers.maxUintValue


enter :
    Address
    -> Int
    -> TokenValue
    -> Maybe Address
    -> Maybe BigInt
    -> TestMode
    -> Call ()
enter userAddress bucketId amount maybeReferrer maybeGasPrice testMode =
    BucketSaleBindings.agreeToTermsAndConditionsListedInThisContractAndEnterSale
        (Config.bucketSaleAddress testMode)
        userAddress
        (BigInt.fromInt bucketId)
        (TokenValue.getEvmValue amount)
        (maybeReferrer |> Maybe.withDefault EthHelpers.zeroAddress)
        |> (\call ->
                { call
                    | gasPrice =
                        maybeGasPrice
                }
           )


exit :
    Address
    -> Int
    -> TestMode
    -> Call ()
exit userAddress bucketId testMode =
    BucketSaleBindings.exit
        (Config.bucketSaleAddress testMode)
        (BigInt.fromInt bucketId)
        userAddress


exitMany :
    Address
    -> List Int
    -> TestMode
    -> Call ()
exitMany userAddress bucketIds testMode =
    BucketSaleBindings.exitMany
        (Config.bucketSaleScriptsAddress testMode)
        (Config.bucketSaleAddress testMode)
        userAddress
        (List.map BigInt.fromInt bucketIds)


queryBigIntListToMaybExitInfo :
    List BigInt
    -> Maybe ExitInfo
queryBigIntListToMaybExitInfo bigIntList =
    case ( List.head bigIntList, List.tail bigIntList ) of
        ( Just totalBigInt, Just idBigInts ) ->
            let
                totalTokenValue =
                    TokenValue.tokenValue totalBigInt
            in
            if TokenValue.isZero totalTokenValue then
                Just <|
                    ExitInfo
                        TokenValue.zero
                        []

            else
                let
                    exitableBucketIds =
                        {-
                           Because of limitations in Solidity, and to reduce scope, what we now have is a huge array
                           of mostly 0s, with the first N values being the id's of the buckets the user can exit from
                           (where N is the number of such buckets).

                           However, if the user can exit from bucket 0, then the first uint will be 0. Fortunately,
                           we now know that the user can exit from SOME buckets (because we're in this 'else'). Therefore,
                           if the first value is 0 it must mean that the 0th bucket is exitable, not that there are no
                           exitable buckets.

                           Therefore we will read the first value of this list as a bucket id straight, then after that
                           value read until we encounter a zero.
                        -}
                        idBigInts
                            |> List.map BigIntHelpers.toIntWithWarning
                            |> List.Extra.uncons
                            |> Maybe.map
                                (\( firstBucketId, otherIdsFollowedByZeroes ) ->
                                    firstBucketId
                                        :: (otherIdsFollowedByZeroes
                                                |> List.Extra.takeWhile ((/=) 0)
                                           )
                                )
                            |> Maybe.withDefault []
                in
                Just <|
                    ExitInfo
                        totalTokenValue
                        exitableBucketIds

        _ ->
            Nothing
