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
import Element.Font
import Eth.Types exposing (Address, Tx, TxHash, TxReceipt)
import Eth.Utils
import Helpers.Element as EH
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
    , fastGasPrice : Maybe BigInt
    , saleStartTime : Maybe Time.Posix
    , bucketSale : BucketSale
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
    , showYoutubeBlock : Bool
    , saleType : SaleType
    }


type Msg
    = NoOp
    | CmdUp (CmdUp Msg)
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
    | BucketValueEnteredFetched Int (Result Http.Error TokenValue)
    | UserBuyFetched Address Int (Result Http.Error BucketSaleBindings.Buy)
    | StateUpdateInfoFetched (Result Http.Error (Maybe BucketSaleWrappers.StateUpdateInfo))
    | TotalTokensExitedFetched (Result Http.Error TokenValue)
    | FocusToBucket Int
    | EnterInputChanged String
    | ReferralIndicatorClicked (Maybe Address)
    | CloseReferralModal (Maybe Address)
    | GenerateReferralClicked Address
    | EnableTokenButtonClicked
    | ClaimClicked UserInfo ExitInfo
    | CancelClicked
    | EnterButtonClicked EnterInfo
    | ConfirmClicked EnterInfo
    | TxSigned Int ActionData (Result String TxHash)
    | TxStatusFetched Int ActionData (Result Http.Error TxReceipt)
    | YoutubeBlockClicked
    | SaleTypeToggleClicked SaleType


type SaleType
    = Standard
    | Advanced


type alias ExtraUserInfo =
    { ethBalance : TokenValue
    , enteringTokenBalance : TokenValue
    , exitingTokenBalance : TokenValue
    , enteringTokenAllowance : TokenValue
    }


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


type alias EnterUXModel =
    { input : String
    , amount : Maybe (Result String TokenValue)
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


updateAllBuckets :
    (BucketData -> BucketData)
    -> BucketSale
    -> BucketSale
updateAllBuckets func bucketSale =
    { bucketSale
        | buckets =
            bucketSale.buckets
                |> List.map func
    }


updateBucketAt :
    Int
    -> (BucketData -> BucketData)
    -> BucketSale
    -> Maybe BucketSale
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


getBucketInfo :
    BucketSale
    -> Int
    -> Time.Posix
    -> TestMode
    -> FetchedBucketInfo
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


getBucketEndTime :
    BucketData
    -> TestMode
    -> Time.Posix
getBucketEndTime bucket testMode =
    TimeHelpers.add
        bucket.startTime
        (Config.bucketSaleBucketInterval testMode)


getFocusedBucketId :
    BucketSale
    -> BucketView
    -> Time.Posix
    -> TestMode
    -> Int
getFocusedBucketId bucketSale bucketView now testMode =
    case bucketView of
        ViewCurrent ->
            getCurrentBucketId bucketSale now testMode

        ViewId id ->
            id


getCurrentBucketId :
    BucketSale
    -> Time.Posix
    -> TestMode
    -> Int
getCurrentBucketId bucketSale now testMode =
    (TimeHelpers.sub now bucketSale.startTime
        |> TimeHelpers.posixToSeconds
    )
        // (Config.bucketSaleBucketInterval testMode
                |> TimeHelpers.posixToSeconds
           )


getCurrentBucket :
    BucketSale
    -> Time.Posix
    -> TestMode
    -> FetchedBucketInfo
getCurrentBucket bucketSale now testMode =
    getBucketInfo
        bucketSale
        (getCurrentBucketId bucketSale now testMode)
        now
        testMode


currentBucketTimeLeft :
    BucketSale
    -> Time.Posix
    -> TestMode
    -> Maybe Time.Posix
currentBucketTimeLeft bucketSale now testMode =
    case getCurrentBucket bucketSale now testMode of
        InvalidBucket ->
            Nothing

        ValidBucket validBucketInfo ->
            Just <|
                TimeHelpers.sub
                    (getBucketEndTime validBucketInfo.bucketData testMode)
                    now


makeBlankBucket :
    TestMode
    -> Time.Posix
    -> Int
    -> BucketData
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


buyFromBindingBuy :
    BucketSaleBindings.Buy
    -> Buy
buyFromBindingBuy bindingBuy =
    Buy
        (TokenValue.tokenValue bindingBuy.valueEntered)
        (BigInt.compare bindingBuy.buyerTokensExited (BigInt.fromInt 0) /= EQ)


calcClaimableTokens :
    TokenValue
    -> TokenValue
    -> TestMode
    -> TokenValue
calcClaimableTokens totalValueEntered tokensIn testMode =
    if TokenValue.isZero tokensIn then
        TokenValue.zero

    else if TokenValue.isZero totalValueEntered then
        Config.bucketSaleTokensPerBucket testMode

    else
        let
            claimableRatio =
                TokenValue.toFloatWithWarning tokensIn
                    / TokenValue.toFloatWithWarning totalValueEntered
        in
        TokenValue.mulFloatWithWarning
            (Config.bucketSaleTokensPerBucket testMode)
            claimableRatio


calcEffectivePricePerToken :
    TokenValue
    -> TestMode
    -> TokenValue
calcEffectivePricePerToken totalValueEntered testMode =
    TokenValue.toFloatWithWarning totalValueEntered
        / (TokenValue.toFloatWithWarning <| Config.bucketSaleTokensPerBucket testMode)
        |> TokenValue.fromFloatWithWarning


type alias RelevantTimingInfo =
    { state : BucketState
    , relevantTimeFromNow : Time.Posix
    }


getRelevantTimingInfo :
    ValidBucketInfo
    -> Time.Posix
    -> TestMode
    -> RelevantTimingInfo
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


maybeReferrerToString :
    Maybe Address
    -> String
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


validateFeedbackInput :
    FeedbackUXModel
    -> Result String ValidatedFeedbackInput
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


updateAnyFeedbackUXErrors :
    FeedbackUXModel
    -> FeedbackUXModel
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


tosLines :
    DisplayProfile
    -> List (List ( List (Element Msg), Maybe String ))
tosLines dProfile =
    case dProfile of
        Desktop ->
            [ [ ( [ Element.text "This constitutes an agreement between you and the Decentralized Autonomous Organization Advancement Institute (\"DAOAI\") ("
                  , Element.newTabLink
                        [ Element.Font.color EH.blue ]
                        { url = "https://foundrydao.com/contact"
                        , label = Element.text "Contact info"
                        }
                  , Element.text ")."
                  ]
                , Just "I understand."
                )
              , ( List.singleton <| Element.text "You are an adult capable of making your own decisions, evaluating your own risks and engaging with others for mutual benefit."
                , Just "I agree."
                )
              , ( [ Element.text "A text version if this agreement can be found "
                  , Element.newTabLink
                        [ Element.Font.color EH.blue ]
                        { url = "https://foundrydao.com/blog/sale-terms"
                        , label = Element.text "here"
                        }
                  , Element.text "."
                  ]
                , Nothing
                )
              ]
            , [ ( List.singleton <| Element.text "Foundry and/or FRY are extremely experimental and could enter into several failure modes."
                , Nothing
                )
              , ( List.singleton <| Element.text "Foundry and/or FRY could fail technically through a software vulnerability."
                , Just "I understand."
                )
              , ( List.singleton <| Element.text "While Foundry and/or FRY have been audited, bugs may have nonetheless snuck through."
                , Just "I understand."
                )
              , ( List.singleton <| Element.text "Foundry and/or FRY could fail due to an economic attack, the details of which might not even be suspected at the time of launch."
                , Just "I understand."
                )
              ]
            , [ ( List.singleton <| Element.text "The projects that Foundry funds may turn out to be flawed technically or have economic attack vectors that make them infeasible."
                , Just "I understand."
                )
              , ( List.singleton <| Element.text "FRY, and the projects funded by Foundry, might never find profitable returns."
                , Just "I understand."
                )
              ]
            , [ ( List.singleton <| Element.text "You will not hold DAOAI liable for damages or losses."
                , Just "I agree."
                )
              , ( List.singleton <| Element.text "Even if you did, DAOAI will be unlikely to have the resources to settle."
                , Just "I understand."
                )
              , ( List.singleton <| Element.text "DAI deposited into this will be held in smart contracts, which DAOAI might not have complete or significant control over."
                , Just "I understand."
                )
              ]
            , [ ( List.singleton <| Element.text "I agree Foundry may track anonymized data about my interactions with the sale."
                , Just "I understand."
                )
              , ( List.singleton <| Element.text "Entering DAI into the sale is irrevocable, even if the bucket has not yet concluded."
                , Just "I understand."
                )
              , ( List.singleton <| Element.text "US citizens and residents are strictly prohibited from this sale."
                , Just "I am not a citizen or resident of the USA."
                )
              ]
            ]

        SmallDesktop ->
            [ [ ( [ Element.paragraph
                        [ Element.Font.size 12 ]
                        [ Element.text "This constitutes an agreement between you and the Decentralized Autonomous Organization Advancement Institute (\"DAOAI\") ("
                        , Element.newTabLink
                            [ Element.Font.color EH.blue ]
                            { url = "https://foundrydao.com/contact"
                            , label = Element.text "Contact info"
                            }
                        , Element.text ")."
                        ]
                  ]
                , Just "I understand."
                )
              , ( List.singleton <|
                    Element.paragraph
                        [ Element.Font.size 12 ]
                        [ Element.text "You are an adult capable of making your own decisions, evaluating your own risks and engaging with others for mutual benefit." ]
                , Just "I agree."
                )
              , ( [ Element.paragraph
                        [ Element.Font.size 12 ]
                        [ Element.text "A text version if this agreement can be found "
                        , Element.newTabLink
                            [ Element.Font.color EH.blue ]
                            { url = "https://foundrydao.com/blog/sale-terms"
                            , label = Element.text "here"
                            }
                        , Element.text "."
                        ]
                  ]
                , Nothing
                )
              ]
            , [ ( List.singleton <|
                    Element.paragraph
                        [ Element.Font.size 12 ]
                        [ Element.text "Foundry and/or FRY are extremely experimental and could enter into several failure modes." ]
                , Nothing
                )
              , ( List.singleton <|
                    Element.paragraph
                        [ Element.Font.size 12 ]
                        [ Element.text "Foundry and/or FRY could fail technically through a software vulnerability." ]
                , Just "I understand."
                )
              , ( List.singleton <|
                    Element.paragraph
                        [ Element.Font.size 12 ]
                        [ Element.text "While Foundry and/or FRY have been audited, bugs may have nonetheless snuck through." ]
                , Just "I understand."
                )
              , ( List.singleton <|
                    Element.paragraph
                        [ Element.Font.size 12 ]
                        [ Element.text "Foundry and/or FRY could fail due to an economic attack, the details of which might not even be suspected at the time of launch." ]
                , Just "I understand."
                )
              ]
            , [ ( List.singleton <|
                    Element.paragraph
                        [ Element.Font.size 12 ]
                        [ Element.text "The projects that Foundry funds may turn out to be flawed technically or have economic attack vectors that make them infeasible." ]
                , Just "I understand."
                )
              , ( List.singleton <|
                    Element.paragraph
                        [ Element.Font.size 12 ]
                        [ Element.text "FRY, and the projects funded by Foundry, might never find profitable returns." ]
                , Just "I understand."
                )
              ]
            , [ ( List.singleton <|
                    Element.paragraph
                        [ Element.Font.size 12 ]
                        [ Element.text "You will not hold DAOAI liable for damages or losses." ]
                , Just "I agree."
                )
              , ( List.singleton <|
                    Element.paragraph
                        [ Element.Font.size 12 ]
                        [ Element.text "Even if you did, DAOAI will be unlikely to have the resources to settle." ]
                , Just "I understand."
                )
              , ( List.singleton <|
                    Element.paragraph
                        [ Element.Font.size 12 ]
                        [ Element.text "DAI deposited into this will be held in smart contracts, which DAOAI might not have complete or significant control over." ]
                , Just "I understand."
                )
              ]
            , [ ( List.singleton <|
                    Element.paragraph
                        [ Element.Font.size 12 ]
                        [ Element.text "I agree Foundry may track anonymized data about my interactions with the sale." ]
                , Just "I understand."
                )
              , ( List.singleton <|
                    Element.paragraph
                        [ Element.Font.size 12 ]
                        [ Element.text "Entering DAI into the sale is irrevocable, even if the bucket has not yet concluded." ]
                , Just "I understand."
                )
              , ( List.singleton <|
                    Element.paragraph
                        [ Element.Font.size 12 ]
                        [ Element.text "US citizens and residents are strictly prohibited from this sale." ]
                , Just "I am not a citizen or resident of the USA."
                )
              ]
            ]
