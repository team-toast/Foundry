module BucketSale.Types exposing (..)

import BigInt exposing (BigInt)
import ChainCmd exposing (ChainCmd)
import CmdUp exposing (CmdUp)
import CommonTypes exposing (..)
import Config
import Contracts.BucketSale.Generated.BucketSale as BucketSaleBindings
import Contracts.BucketSale.Wrappers as BucketSaleWrappers exposing (ExitInfo)
import Dict exposing (Dict)
import Element exposing (Element)
import Eth.Types exposing (Address, Tx, TxHash, TxReceipt)
import Eth.Utils
import Helpers.Eth as EthHelpers
import Helpers.Time as TimeHelpers
import Http
import Json.Decode
import List.Extra
import String.Extra
import Time
import TokenValue exposing (TokenValue)
import Validate
import Wallet


type alias Model =
    { wallet : Wallet.State
    , extraUserInfo : Maybe BucketSaleWrappers.UserStateInfo
    , testMode : TestMode
    , now : Time.Posix
    , timezone : Maybe Time.Zone
    , fastGasPrice : Maybe BigInt
    , saleStartTime : Maybe Time.Posix
    , bucketSale : Maybe (Result String BucketSale)
    , totalTokensExited : Maybe TokenValue
    , bucketView : BucketView
    , jurisdictionCheckStatus : JurisdictionCheckStatus
    , enterUXModel : EnterUXModel
    , trackedTxs : List TrackedTx
    , confirmTosModel : ConfirmTosModel
    , enterInfoToConfirm : Maybe EnterInfo
    , showReferralModal : Bool
    , showFeedbackUXModel : Bool
    , feedbackUXModel : FeedbackUXModel
    }


type alias ExtraUserInfo =
    { ethBalance : TokenValue
    , daiBalance : TokenValue
    , fryBalance : TokenValue
    , daiAllowance : TokenValue
    }


type alias EnterUXModel =
    { daiInput : String
    , daiAmount : Maybe (Result String TokenValue)
    , referrer : Maybe Address
    }


type alias ConfirmTosModel =
    { points : List (List TosCheckbox) -- List of lists, where each list is another page
    , page : Int
    }


isAllPointsChecked : ConfirmTosModel -> Bool
isAllPointsChecked agreeToTosModel =
    List.all
        (List.all
            (\tosPoint ->
                case tosPoint.maybeCheckedString of
                    Nothing ->
                        True

                    Just ( _, isChecked ) ->
                        isChecked
            )
        )
        agreeToTosModel.points


type alias TosCheckbox =
    { textEls : List (Element Msg)
    , maybeCheckedString : Maybe ( String, Bool )
    }


type Msg
    = NoOp
    | CmdUp (CmdUp Msg)
    | TimezoneGot Time.Zone
    | Refresh
    | UpdateNow Time.Posix
    | FetchFastGasPrice
    | FetchedFastGasPrice (Result Http.Error BigInt)
    | TosPreviousPageClicked
    | TosNextPageClicked
    | TosCheckboxClicked ( Int, Int )
    | AddFryToMetaMaskClicked
    | VerifyJurisdictionClicked
    | FeedbackButtonClicked
    | FeedbackEmailChanged String
    | FeedbackDescriptionChanged String
    | FeedbackSubmitClicked
    | FeedbackHttpResponse (Result Http.Error String)
    | FeedbackBackClicked
    | FeedbackSendMoreClicked
    | LocationCheckResult (Result Json.Decode.Error (Result String LocationInfo))
    | SaleStartTimestampFetched (Result Http.Error BigInt)
    | BucketValueEnteredFetched Int (Result Http.Error TokenValue)
    | UserBuyFetched Address Int (Result Http.Error BucketSaleBindings.Buy)
    | StateUpdateInfoFetched (Result Http.Error (Maybe BucketSaleWrappers.StateUpdateInfo))
    | TotalTokensExitedFetched (Result Http.Error TokenValue)
    | FocusToBucket Int
    | DaiInputChanged String
    | ReferralIndicatorClicked
    | CloseReferralModal
    | GenerateReferralClicked Address
    | UnlockDaiButtonClicked
    | ClaimClicked UserInfo ExitInfo
    | CancelClicked
    | EnterButtonClicked EnterInfo
    | ConfirmClicked EnterInfo
    | TxSigned Int ActionData (Result String TxHash)
    | TxStatusFetched Int ActionData (Result Http.Error TxReceipt)


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


type alias EnterInfo =
    { userInfo : UserInfo
    , bucketId : Int
    , amount : TokenValue
    , maybeReferrer : Maybe Address
    }


type alias TrackedTx =
    { action : ActionData
    , status : TxStatus
    }


type ActionData
    = Unlock
    | Enter EnterInfo
    | Exit


actionDataToString : ActionData -> String
actionDataToString actionData =
    case actionData of
        Unlock ->
            "Unlock"

        Enter _ ->
            "Enter"

        Exit ->
            "Exit"


type TxStatus
    = Signing
    | Rejected
    | Signed TxHash SignedTxStatus


type SignedTxStatus
    = Mining
    | Success
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


type alias LocationInfo =
    { ipCode : String
    , geoCode : String
    , distanceKm : Float
    }


type CountryInfo
    = Matching String
    | NotMatching


type Jurisdiction
    = ForbiddenJurisdictions
    | JurisdictionsWeArentIntimidatedIntoExcluding


type JurisdictionCheckStatus
    = WaitingForClick
    | Checking
    | Checked Jurisdiction
    | Error String


maybeReferrerToString : Maybe Address -> String
maybeReferrerToString =
    Maybe.map Eth.Utils.addressToString
        >> Maybe.withDefault "no referrer"


type alias FeedbackUXModel =
    { email : String
    , description : String
    , debugString : Maybe String
    , sendState : FeedbackSendState
    , maybeError : Maybe String
    }


type FeedbackSendState
    = NotSent
    | Sending
    | SendFailed String
    | Sent


initFeedbackUXModel : FeedbackUXModel
initFeedbackUXModel =
    FeedbackUXModel
        ""
        ""
        Nothing
        NotSent
        Nothing


validateFeedbackInput : FeedbackUXModel -> Result String ValidatedFeedbackInput
validateFeedbackInput feedbackUXModel =
    if String.isEmpty feedbackUXModel.description then
        Err "Description is required."

    else if String.isEmpty feedbackUXModel.email || Validate.isValidEmail feedbackUXModel.email then
        Ok <|
            ValidatedFeedbackInput
                (String.Extra.nonEmpty feedbackUXModel.email)
                feedbackUXModel.description
                feedbackUXModel.debugString

    else
        Err <|
            "Email is invalid."


updateAnyFeedbackUXErrors : FeedbackUXModel -> FeedbackUXModel
updateAnyFeedbackUXErrors feedbackUXModel =
    case feedbackUXModel.maybeError of
        Nothing ->
            feedbackUXModel

        Just err ->
            { feedbackUXModel
                | maybeError =
                    case validateFeedbackInput feedbackUXModel of
                        Ok _ ->
                            Nothing

                        Err errStr ->
                            Just errStr
            }


type alias ValidatedFeedbackInput =
    { email : Maybe String
    , description : String
    , debugString : Maybe String
    }
