module BucketSale.Types exposing (..)

import BigInt exposing (BigInt)
import ChainCmd exposing (ChainCmd)
import CmdUp exposing (CmdUp)
import CommonTypes exposing (..)
import Config
import Contracts.BucketSale.Generated.BucketSale as BucketSaleBindings
import Contracts.BucketSale.Wrappers as BucketSaleWrappers exposing (ExitInfo)
import Dict exposing (Dict)
import Eth.Types exposing (Address, Tx, TxHash, TxReceipt)
import Helpers.Eth as EthHelpers
import Helpers.Time as TimeHelpers
import Http
import List.Extra
import Time
import TokenValue exposing (TokenValue)
import Wallet


type alias Model =
    { wallet : Wallet.State
    , testMode : TestMode
    , now : Time.Posix
    , timezone : Maybe Time.Zone
    , saleStartTime : Maybe Time.Posix
    , bucketSale : Maybe (Result String BucketSale)
    , totalTokensExited : Maybe TokenValue
    , userFryBalance : Maybe TokenValue
    , bucketView : BucketView
    , jurisdictionCheckStatus : JurisdictionCheckStatus
    , enterUXModel : EnterUXModel
    , userExitInfo : Maybe BucketSaleWrappers.ExitInfo
    , trackedTxs : List TrackedTx
    , confirmModal : Maybe EnterInfo
    , showReferralModal : Bool
    }


type alias EnterUXModel =
    { daiInput : String
    , daiAmount : Maybe (Result String TokenValue)
    , referrer : Maybe Address
    , allowance : Maybe TokenValue
    }


type Msg
    = NoOp
    | CmdUp (CmdUp Msg)
    | TimezoneGot Time.Zone
    | Refresh
    | UpdateNow Time.Posix
    | JurisdictionFetched (Result Http.Error Jurisdiction)
    | SaleStartTimestampFetched (Result Http.Error BigInt)
    | BucketValueEnteredFetched Int (Result Http.Error TokenValue)
    | UserBuyFetched Address Int (Result Http.Error BucketSaleBindings.Buy)
    | UserExitInfoFetched Address (Result Http.Error (Maybe BucketSaleWrappers.ExitInfo))
    | TotalTokensExitedFetched (Result Http.Error TokenValue)
    | UserFryBalanceFetched Address (Result Http.Error TokenValue)
    | FocusToBucket Int
    | DaiInputChanged String
    | ReferralIndicatorClicked
    | CloseReferralModal
    | GenerateReferralClicked Address
    | UnlockDaiButtonClicked
    | AllowanceFetched (Result Http.Error BigInt)
    | ClaimClicked UserInfo ExitInfo
    | CancelClicked
    | EnterButtonClicked EnterInfo
    | ConfirmClicked EnterInfo
    | TxSigned Int ActionData (Result String TxHash)
    | TxBroadcast Int ActionData (Result String Tx)
    | TxMined Int ActionData (Result String TxReceipt)


type alias UpdateResult =
    { model : Model
    , cmd : Cmd Msg
    , chainCmd : ChainCmd Msg
    , cmdUps : List (CmdUp Msg)
    }


justModelUpdate : Model -> UpdateResult
justModelUpdate model =
    { model = model
    , cmd = Cmd.none
    , chainCmd = ChainCmd.none
    , cmdUps = []
    }

type JurisdictionCheckStatus
    = Checking
    | Excluded
    | Allowed
    | FetchError Http.Error

type alias EnterInfo =
    { userInfo : UserInfo
    , bucketId : Int
    , amount : TokenValue
    , maybeReferrer : Maybe Address
    }


type alias TrackedTx =
    { hash : Maybe TxHash
    , action : ActionData
    , status : TxStatus
    }


type ActionData
    = Unlock
    | Enter EnterInfo
    | Exit


type TxStatus
    = Signing
    | Broadcasting
    | Mining
    | Mined
    | Rejected
    | Failed


type BucketView
    = ViewCurrent
    | ViewId Int


type alias BucketSale =
    { startTime : Time.Posix
    , buckets : List BucketData
    }


type FetchedBucketInfo
    = InvalidBucket
    | ValidBucket ValidBucketInfo


type alias ValidBucketInfo =
    { id : Int
    , state : BucketState
    , bucketData : BucketData
    }


type alias BucketData =
    { startTime : Time.Posix
    , totalValueEntered : Maybe TokenValue
    , userBuy : Maybe Buy
    }


type BucketState
    = Closed
    | Current
    | Future


type alias Buy =
    { valueEntered : TokenValue
    , hasExited : Bool
    }


updateAllBuckets : (BucketData -> BucketData) -> BucketSale -> BucketSale
updateAllBuckets func bucketSale =
    { bucketSale
        | buckets =
            bucketSale.buckets
                |> List.map func
    }


updateBucketAt : Int -> (BucketData -> BucketData) -> BucketSale -> Maybe BucketSale
updateBucketAt id func bucketSale =
    if id < List.length bucketSale.buckets then
        Just
            { bucketSale
                | buckets =
                    bucketSale.buckets
                        |> List.Extra.updateAt id func
            }

    else
        Nothing


getBucketInfo : BucketSale -> Int -> Time.Posix -> TestMode -> FetchedBucketInfo
getBucketInfo bucketSale bucketId now testMode =
    List.Extra.getAt bucketId bucketSale.buckets
        |> Maybe.map
            (\bucket ->
                ValidBucket <|
                    ValidBucketInfo
                        bucketId
                        (if TimeHelpers.compare bucket.startTime now == GT then
                            Future

                         else if TimeHelpers.compare (getBucketEndTime bucket testMode) now == GT then
                            Current

                         else
                            Closed
                        )
                        bucket
            )
        |> Maybe.withDefault InvalidBucket


getBucketEndTime : BucketData -> TestMode -> Time.Posix
getBucketEndTime bucket testMode =
    TimeHelpers.add
        bucket.startTime
        (Config.bucketSaleBucketInterval testMode)


getFocusedBucketId : BucketSale -> BucketView -> Time.Posix -> TestMode -> Int
getFocusedBucketId bucketSale bucketView now testMode =
    case bucketView of
        ViewCurrent ->
            getCurrentBucketId bucketSale now testMode

        ViewId id ->
            id


getCurrentBucketId : BucketSale -> Time.Posix -> TestMode -> Int
getCurrentBucketId bucketSale now testMode =
    (TimeHelpers.sub now bucketSale.startTime
        |> TimeHelpers.posixToSeconds
    )
        // (Config.bucketSaleBucketInterval testMode
                |> TimeHelpers.posixToSeconds
           )


getCurrentBucket : BucketSale -> Time.Posix -> TestMode -> FetchedBucketInfo
getCurrentBucket bucketSale now testMode =
    getBucketInfo
        bucketSale
        (getCurrentBucketId bucketSale now testMode)
        now
        testMode


currentBucketTimeLeft : BucketSale -> Time.Posix -> TestMode -> Maybe Time.Posix
currentBucketTimeLeft bucketSale now testMode =
    case getCurrentBucket bucketSale now testMode of
        InvalidBucket ->
            Nothing

        ValidBucket validBucketInfo ->
            Just <|
                TimeHelpers.sub
                    (getBucketEndTime validBucketInfo.bucketData testMode)
                    now


makeBlankBucket : TestMode -> Time.Posix -> Int -> BucketData
makeBlankBucket testMode bucketSaleStartTime bucketId =
    BucketData
        (TimeHelpers.posixToSeconds bucketSaleStartTime
            + (TimeHelpers.posixToSeconds (Config.bucketSaleBucketInterval testMode)
                * bucketId
              )
            |> TimeHelpers.secondsToPosix
        )
        Nothing
        Nothing


buyFromBindingBuy : BucketSaleBindings.Buy -> Buy
buyFromBindingBuy bindingBuy =
    Buy
        (TokenValue.tokenValue bindingBuy.valueEntered)
        (BigInt.compare bindingBuy.buyerTokensExited (BigInt.fromInt 0) /= EQ)


calcClaimableTokens : TokenValue -> TokenValue -> TestMode -> TokenValue
calcClaimableTokens totalValueEntered daiIn testMode =
    if TokenValue.isZero daiIn then
        TokenValue.zero

    else if TokenValue.isZero totalValueEntered then
        Config.bucketSaleTokensPerBucket testMode

    else
        let
            claimableRatio =
                TokenValue.toFloatWithWarning daiIn
                    / TokenValue.toFloatWithWarning totalValueEntered
        in
        TokenValue.mulFloatWithWarning
            (Config.bucketSaleTokensPerBucket testMode)
            claimableRatio


calcEffectivePricePerToken : TokenValue -> TestMode -> TokenValue
calcEffectivePricePerToken totalValueEntered testMode =
    TokenValue.toFloatWithWarning totalValueEntered
        / (TokenValue.toFloatWithWarning <| Config.bucketSaleTokensPerBucket testMode)
        |> TokenValue.fromFloatWithWarning


type alias RelevantTimingInfo =
    { state : BucketState
    , relevantTimeFromNow : Time.Posix
    }


getRelevantTimingInfo : ValidBucketInfo -> Time.Posix -> TestMode -> RelevantTimingInfo
getRelevantTimingInfo bucketInfo now testMode =
    RelevantTimingInfo
        bucketInfo.state
        (case bucketInfo.state of
            Closed ->
                -- How long ago did the bucket end?
                TimeHelpers.sub
                    now
                    bucketInfo.bucketData.startTime

            Current ->
                -- How soon will the bucket end?
                TimeHelpers.sub
                    (getBucketEndTime bucketInfo.bucketData testMode)
                    now

            Future ->
                -- How soon will the bucket start?
                TimeHelpers.sub
                    bucketInfo.bucketData.startTime
                    now
        )

type Jurisdiction
    = ChinaOrUSA
    | JurisdictionsWeArentIntimidatedIntoExcluding
