module BucketSale.View exposing (bidImpactParagraphEl, root)

import BigInt exposing (BigInt)
import BucketSale.Types exposing (..)
import CmdUp exposing (CmdUp)
import Color
import CommonTypes exposing (..)
import Config
import Contracts.BucketSale.Wrappers exposing (ExitInfo, UserStateInfo)
import Css exposing (true)
import Element exposing (Attribute, Element)
import Element.Background
import Element.Border
import Element.Events
import Element.Font
import Element.Input
import Eth.Types exposing (Address)
import Eth.Utils
import FormatFloat exposing (formatFloat)
import Helpers.Element as EH
import Helpers.Eth as EthHelpers
import Helpers.Time as TimeHelpers
import Html.Attributes
import Images exposing (Image)
import List.Extra
import Maybe.Extra
import Result.Extra
import Routing
import Time
import TokenValue exposing (TokenValue, toConciseString)
import Wallet


root :
    DisplayProfile
    -> Model
    -> Maybe Address
    -> ( Element Msg, List (Element Msg) )
root dProfile model maybeReferrer =
    let
        paneToShow =
            case model.saleType of
                Standard ->
                    focusedBucketPane

                Advanced ->
                    multiBucketPane
    in
    ( Element.column
        ([ Element.width Element.fill
         , Element.paddingEach
            { bottom = 40
            , top = 0
            , right = 0
            , left = 0
            }
         ]
            ++ (List.map Element.inFront <|
                    viewModals
                        dProfile
                        model
                        maybeReferrer
               )
        )
        (case dProfile of
            Desktop ->
                [ Element.row
                    [ Element.centerX
                    , Element.spacing 50
                    ]
                    [ Element.column
                        [ Element.width <| Element.fillPortion 1
                        , Element.alignTop
                        , Element.spacing 20
                        ]
                        [ viewYoutubeLinksBlock dProfile True
                        , closedBucketsPane dProfile model
                        ]
                    , Element.column
                        [ Element.width <| Element.fillPortion 2
                        , Element.spacing 20
                        , Element.alignTop
                        ]
                        [ paneToShow
                            dProfile
                            maybeReferrer
                            model.bucketSale
                            (getFocusedBucketId
                                model.bucketSale
                                model.bucketView
                                model.now
                                model.testMode
                            )
                            model.wallet
                            model.extraUserInfo
                            model.enterUXModel
                            model.jurisdictionCheckStatus
                            model.trackedTxs
                            model.showReferralModal
                            model.now
                            model.saleType
                            model.testMode
                        ]
                    , Element.column
                        [ Element.spacing 20
                        , Element.width Element.fill
                        , Element.alignTop
                        ]
                        [ feedbackButtonBlock model.showFeedbackUXModel model.feedbackUXModel
                        , futureBucketsPane dProfile model
                        , trackedTxsElement model.trackedTxs
                        ]
                    ]
                ]

            SmallDesktop ->
                [ Element.column
                    [ Element.width Element.fill
                    , Element.spacing 5
                    ]
                    [ viewYoutubeLinksBlock dProfile model.showYoutubeBlock
                    , paneToShow
                        dProfile
                        maybeReferrer
                        model.bucketSale
                        (getFocusedBucketId
                            model.bucketSale
                            model.bucketView
                            model.now
                            model.testMode
                        )
                        model.wallet
                        model.extraUserInfo
                        model.enterUXModel
                        model.jurisdictionCheckStatus
                        model.trackedTxs
                        model.showReferralModal
                        model.now
                        model.saleType
                        model.testMode
                    ]
                ]
        )
    , []
    )


commonPaneAttributes : List (Attribute Msg)
commonPaneAttributes =
    [ Element.Background.color EH.white
    , Element.spacing 20
    , Element.Border.rounded 8
    , Element.centerY
    , Element.Border.shadow
        { offset = ( 0, 3 )
        , size = 0
        , blur = 20
        , color = Element.rgba 0 0 0 0.06
        }
    ]


blockTitleText : String -> List (Attribute Msg) -> Element Msg
blockTitleText text attributes =
    Element.el
        ([ Element.width Element.fill
         , Element.Font.size 25
         , Element.Font.bold
         ]
            ++ attributes
        )
    <|
        Element.text text


saleTypeBlock :
    DisplayProfile
    -> SaleType
    -> Element Msg
saleTypeBlock dProfile saleType =
    let
        toggleStandardBgColor =
            case saleType of
                Standard ->
                    EH.lightBlue

                Advanced ->
                    EH.lightGray

        toggleAdvancedBgColor =
            case saleType of
                Standard ->
                    EH.lightGray

                Advanced ->
                    EH.lightBlue

        saleTypeAttributes =
            [ Element.Border.rounded 10
            , Element.padding <| responsiveVal dProfile 10 5
            , Element.Font.size <| responsiveVal dProfile 16 12
            ]
    in
    Element.row
        [ Element.centerX
        , Element.spacing 2
        ]
        [ Element.el
            (saleTypeAttributes
                ++ [ Element.Events.onClick <|
                        SaleTypeToggleClicked Standard
                   , Element.pointer
                   , Element.Background.color toggleStandardBgColor
                   ]
            )
          <|
            Element.text "Standard"
        , Element.el
            (saleTypeAttributes
                ++ [ Element.Events.onClick <|
                        SaleTypeToggleClicked Advanced
                   , Element.pointer
                   , Element.Background.color toggleAdvancedBgColor
                   ]
            )
          <|
            Element.text "Advanced"
        ]


closedBucketsPane : DisplayProfile -> Model -> Element Msg
closedBucketsPane dProfile model =
    Element.column
        (commonPaneAttributes
            ++ [ Element.width Element.fill
               , Element.paddingXY 32 25
               ]
        )
        [ blockTitleText "Concluded Buckets" []
        , Element.paragraph
            [ Element.Font.color grayTextColor
            , Element.Font.size 15
            ]
            [ Element.text <|
                "These are the concluded buckets of "
                    ++ Config.exitingTokenCurrencyLabel
                    ++ " that have been claimed. If you have "
                    ++ Config.exitingTokenCurrencyLabel
                    ++ " to claim it will show below."
            ]
        , maybeUserBalanceBlock
            dProfile
            model.wallet
            model.extraUserInfo
        , maybeClaimBlock
            dProfile
            model.wallet
            (model.extraUserInfo |> Maybe.map .exitInfo)
        , totalExitedBlock
            dProfile
            model.totalTokensExited
        ]


focusedBucketPane :
    DisplayProfile
    -> Maybe Address
    -> BucketSale
    -> Int
    -> Wallet.State
    -> Maybe UserStateInfo
    -> EnterUXModel
    -> JurisdictionCheckStatus
    -> List TrackedTx
    -> Bool
    -> Time.Posix
    -> SaleType
    -> TestMode
    -> Element Msg
focusedBucketPane dProfile maybeReferrer bucketSale bucketId wallet maybeExtraUserInfo enterUXModel jurisdictionCheckStatus trackedTxs referralModalActive now saleType testMode =
    Element.column
        (commonPaneAttributes
            ++ [ Element.width Element.fill
               , Element.paddingXY
                    (responsiveVal dProfile 35 16)
                    (responsiveVal dProfile 15 7)
               , Element.spacing
                    (responsiveVal dProfile 7 3)
               ]
        )
        ([ focusedBucketHeaderEl
            dProfile
            bucketId
            (getCurrentBucketId bucketSale now testMode)
            (Wallet.userInfo wallet)
            maybeReferrer
            referralModalActive
            saleType
            testMode
         ]
            ++ (case getBucketInfo bucketSale bucketId now testMode of
                    InvalidBucket ->
                        [ Element.el
                            [ Element.Font.size 20
                            , Element.centerX
                            ]
                            (Element.text "Invalid bucket Id")
                        ]

                    ValidBucket bucketInfo ->
                        case bucketInfo.state of
                            Closed ->
                                [ focusedBucketClosedPane
                                    dProfile
                                    bucketInfo
                                    (getRelevantTimingInfo bucketInfo now testMode)
                                    wallet
                                    testMode
                                ]

                            _ ->
                                [ focusedBucketSubheaderEl
                                    dProfile
                                    bucketInfo
                                , focusedBucketTimeLeftEl
                                    dProfile
                                    (getRelevantTimingInfo bucketInfo now testMode)
                                    testMode
                                , bucketUX
                                    dProfile
                                    wallet
                                    maybeReferrer
                                    maybeExtraUserInfo
                                    enterUXModel
                                    bucketInfo
                                    jurisdictionCheckStatus
                                    trackedTxs
                                    saleType
                                    testMode
                                ]
               )
        )


multiBucketPane :
    DisplayProfile
    -> Maybe Address
    -> BucketSale
    -> Int
    -> Wallet.State
    -> Maybe UserStateInfo
    -> EnterUXModel
    -> JurisdictionCheckStatus
    -> List TrackedTx
    -> Bool
    -> Time.Posix
    -> SaleType
    -> TestMode
    -> Element Msg
multiBucketPane dProfile maybeReferrer bucketSale bucketId wallet maybeExtraUserInfo enterUXModel jurisdictionCheckStatus trackedTxs referralModalActive now saleType testMode =
    let
        unlockMining =
            trackedTxs
                |> List.any
                    (\trackedTx ->
                        case trackedTx.action of
                            Unlock ->
                                case trackedTx.status of
                                    Signed _ Mining ->
                                        True

                                    _ ->
                                        False

                            _ ->
                                False
                    )

        currentBucketId =
            getCurrentBucketId
                bucketSale
                now
                testMode

        fontSize =
            responsiveVal dProfile 20 12

        inputWidth =
            responsiveVal dProfile 80 70

        inputHeight =
            responsiveVal dProfile 50 30
    in
    Element.column
        (commonPaneAttributes
            ++ [ Element.width Element.fill
               , Element.paddingXY
                    (responsiveVal dProfile 35 16)
                    (responsiveVal dProfile 15 7)
               , Element.spacing
                    (responsiveVal dProfile 7 3)
               ]
        )
        ([ maybeReferralIndicatorAndModal
            dProfile
            (Wallet.userInfo wallet)
            maybeReferrer
            referralModalActive
            saleType
            testMode
         ]
            ++ (case getBucketInfo bucketSale bucketId now testMode of
                    InvalidBucket ->
                        [ Element.el
                            [ Element.Font.size fontSize
                            , Element.centerX
                            ]
                            (Element.text "Invalid bucket Id")
                        ]

                    ValidBucket bucketInfo ->
                        [ bidInputBlock
                            dProfile
                            enterUXModel
                            bucketInfo
                            saleType
                            testMode
                        , centerpaneBlockContainer
                            dProfile
                            ActiveStyle
                            [ Element.Font.color EH.darkGray ]
                            [ Element.column
                                [ Element.width Element.fill
                                , Element.spacing 5
                                ]
                                [ Element.el
                                    [ Element.Font.size fontSize
                                    ]
                                  <|
                                    Element.text "Start bid at bucket: "
                                , Element.row
                                    [ Element.width Element.fill
                                    ]
                                    [ Element.Input.text
                                        [ Element.width <| Element.px inputWidth
                                        , Element.Font.color EH.darkGray
                                        , Element.Font.size fontSize
                                        ]
                                        { onChange = MultiBucketFromBucketChanged
                                        , text = enterUXModel.fromBucket
                                        , label = Element.Input.labelHidden "starting bucket"
                                        , placeholder = Nothing
                                        }
                                    , Element.text <| "  (min " ++ String.fromInt currentBucketId ++ ")"
                                    ]
                                , Element.el
                                    [ Element.Font.size fontSize
                                    , Element.paddingEach { edges | top = 10 }
                                    ]
                                  <|
                                    Element.text "Number of buckets to bid on: "
                                , Element.row
                                    [ Element.width Element.fill
                                    ]
                                    [ Element.Input.text
                                        [ Element.width <| Element.px inputWidth
                                        , Element.Font.color EH.darkGray
                                        , Element.Font.size fontSize
                                        ]
                                        { onChange = MultiBucketNumberOfBucketsChanged
                                        , text = enterUXModel.nrBuckets
                                        , label = Element.Input.labelHidden "number of buckets"
                                        , placeholder = Nothing
                                        }
                                    , Element.text "  (max 100)"
                                    ]
                                ]
                            ]
                        , let
                            inputAmount =
                                enterUXModel.amount
                                    |> Maybe.map Result.toMaybe
                                    |> Maybe.Extra.join
                                    |> Maybe.withDefault TokenValue.zero

                            nrBuckets =
                                enterUXModel.nrBucketsInt
                                    |> Maybe.map Result.toMaybe
                                    |> Maybe.Extra.join
                                    |> Maybe.withDefault 1
                                    |> toFloat

                            fromBucket =
                                enterUXModel.fromBucketId
                                    |> Maybe.map Result.toMaybe
                                    |> Maybe.Extra.join
                                    |> Maybe.withDefault bucketId

                            daiPerBucket =
                                String.fromFloat (TokenValue.toFloatWithWarning inputAmount / nrBuckets)
                          in
                          case enterUXModel.fromBucketId of
                            Just (Ok startBucket) ->
                                case enterUXModel.nrBucketsInt of
                                    Just (Ok numberBuckets) ->
                                        case enterUXModel.amount of
                                            Just (Ok amount) ->
                                                Element.paragraph
                                                    [ Element.Font.size fontSize ]
                                                    [ Element.text <|
                                                        "You will bid "
                                                            ++ daiPerBucket
                                                            ++ " "
                                                            ++ Config.enteringTokenCurrencyLabel
                                                            ++ " per bucket "
                                                            ++ " over the next "
                                                            ++ String.fromFloat nrBuckets
                                                            ++ " buckets, starting at bucket #"
                                                            ++ String.fromInt fromBucket
                                                    ]

                                            _ ->
                                                Element.none

                                    _ ->
                                        Element.none

                            _ ->
                                Element.none
                        , actionButton
                            dProfile
                            jurisdictionCheckStatus
                            maybeReferrer
                            wallet
                            maybeExtraUserInfo
                            unlockMining
                            enterUXModel
                            bucketInfo
                            trackedTxs
                            saleType
                            testMode
                        ]
               )
        )


focusedBucketClosedPane :
    DisplayProfile
    -> ValidBucketInfo
    -> RelevantTimingInfo
    -> Wallet.State
    -> TestMode
    -> Element Msg
focusedBucketClosedPane dProfile bucketInfo timingInfo wallet testMode =
    let
        intervalString =
            TimeHelpers.toConciseIntervalString timingInfo.relevantTimeFromNow

        totalValueEntered =
            case bucketInfo.bucketData.totalValueEntered of
                Just totalEntered ->
                    totalEntered

                _ ->
                    TokenValue.zero

        userBuy =
            case bucketInfo.bucketData.userBuy of
                Just buy ->
                    buy.valueEntered

                _ ->
                    TokenValue.zero

        para =
            Element.paragraph
                [ Element.width Element.fill
                , Element.Font.color grayTextColor
                , Element.paddingXY 0 10
                ]
    in
    centerpaneBlockContainer
        dProfile
        PassiveStyle
        (case dProfile of
            Desktop ->
                [ Element.height <| Element.px 310 ]

            SmallDesktop ->
                []
        )
    <|
        [ Element.column
            [ Element.padding 5
            , Element.Font.size (responsiveVal dProfile 16 10)
            , Element.width Element.fill
            ]
            [ para <|
                [ Element.text "Bucket "
                , emphasizedText PassiveStyle <|
                    String.fromInt bucketInfo.id
                , Element.text " ended "
                , emphasizedText PassiveStyle <|
                    intervalString
                , Element.text " ago."
                ]
            , bidBarEl totalValueEntered ( userBuy, TokenValue.zero, TokenValue.zero ) testMode
            , para <|
                [ Element.text <|
                    "The price for "
                        ++ Config.exitingTokenCurrencyLabel
                        ++ " on this bucket was "
                , emphasizedText PassiveStyle <|
                    (calcEffectivePricePerToken
                        totalValueEntered
                        testMode
                        |> TokenValue.toConciseString
                    )
                        ++ " "
                        ++ Config.enteringTokenCurrencyLabel
                        ++ "/"
                        ++ Config.exitingTokenCurrencyLabel
                        ++ "."
                ]
            ]
        ]


futureBucketsPane : DisplayProfile -> Model -> Element Msg
futureBucketsPane dProfile model =
    let
        fetchedNextBucketInfo =
            getBucketInfo
                model.bucketSale
                (getCurrentBucketId
                    model.bucketSale
                    model.now
                    model.testMode
                    + 1
                )
                model.now
                model.testMode
    in
    case fetchedNextBucketInfo of
        InvalidBucket ->
            noBucketsLeftBlock

        ValidBucket nextBucketInfo ->
            Element.column
                (commonPaneAttributes
                    ++ [ Element.width <| Element.fillPortion 1
                       , Element.paddingXY (responsiveVal dProfile 32 16) (responsiveVal dProfile 25 12)
                       ]
                )
                [ blockTitleText "Future Buckets" []
                , Element.paragraph
                    [ Element.Font.color grayTextColor
                    , Element.Font.size 15
                    ]
                    [ Element.text "These are the upcoming buckets set to be released. The next bucket will begin in "
                    , emphasizedText PassiveStyle <|
                        TimeHelpers.toConciseIntervalString <|
                            TimeHelpers.sub
                                nextBucketInfo.bucketData.startTime
                                model.now
                    ]
                , maybeBucketsLeftBlock
                    dProfile
                    model.bucketSale
                    model.now
                    model.testMode
                , maybeSoldTokenInFutureBucketsBlock
                    dProfile
                    model.bucketSale
                    model.now
                    model.testMode
                ]


feedbackButtonBlock : Bool -> FeedbackUXModel -> Element Msg
feedbackButtonBlock showFeedbackUXModel feedbackUXModel =
    Element.column
        (commonPaneAttributes
            ++ [ Element.width <| Element.fillPortion 1
               , Element.paddingXY 32 25
               ]
        )
        [ blockTitleText "Having issues?" []
        , if showFeedbackUXModel then
            viewFeedbackForm feedbackUXModel

          else
            EH.blueButton
                Desktop
                [ Element.centerX ]
                [ "Leave Feedback / Get Help" ]
                FeedbackButtonClicked
        ]


viewFeedbackForm : FeedbackUXModel -> Element Msg
viewFeedbackForm feedbackUXModel =
    let
        inputHeader text =
            Element.el
                []
            <|
                Element.text text

        withHeader text el =
            Element.column
                [ Element.spacing 5
                , Element.width Element.fill
                ]
                [ inputHeader text
                , el
                ]

        textElInsteadOfButton color text =
            Element.paragraph
                [ Element.Font.color color
                , Element.Font.italic
                ]
            <|
                [ Element.text text ]

        errorEls =
            [ case feedbackUXModel.maybeError of
                Just inputErrStr ->
                    textElInsteadOfButton EH.softRed inputErrStr

                Nothing ->
                    Element.none
            , case feedbackUXModel.sendState of
                SendFailed sendErrStr ->
                    textElInsteadOfButton EH.softRed <| "Submit failed: " ++ sendErrStr

                _ ->
                    Element.none
            ]

        submitFeedbackButton text =
            EH.blueButton
                Desktop
                [ Element.alignLeft ]
                [ text ]
                FeedbackSubmitClicked

        backButton =
            EH.lightBlueButton
                Desktop
                [ Element.alignRight ]
                [ "Back" ]
                FeedbackBackClicked

        submitButtonOrMsg =
            case feedbackUXModel.sendState of
                Sending ->
                    textElInsteadOfButton EH.blue "Sending..."

                Sent ->
                    Element.column
                        [ Element.spacing 5
                        , Element.width Element.fill
                        ]
                        [ textElInsteadOfButton EH.green
                            ("Sent!"
                                ++ (if feedbackUXModel.email == "" then
                                        ""

                                    else
                                        " We'll be in contact."
                                   )
                            )
                        , Element.el
                            [ Element.Font.color EH.lightBlue
                            , Element.pointer
                            , Element.Events.onClick FeedbackSendMoreClicked
                            ]
                            (Element.text "Send More")
                        ]

                SendFailed sendErrStr ->
                    submitFeedbackButton "Try Again"

                NotSent ->
                    submitFeedbackButton "Submit"
    in
    Element.column
        [ Element.width Element.fill
        , Element.spacing 20
        ]
        ([ withHeader "Email address (optional)" <|
            Element.Input.text
                [ Element.width Element.fill ]
                { onChange = FeedbackEmailChanged
                , text = feedbackUXModel.email
                , placeholder = Nothing
                , label = Element.Input.labelHidden "email"
                }
         , withHeader "What's the problem?" <|
            Element.Input.multiline
                [ Element.width Element.fill
                , Element.height <| Element.px 300
                ]
                { onChange = FeedbackDescriptionChanged
                , text = feedbackUXModel.description
                , placeholder = Nothing
                , label = Element.Input.labelHidden "problem description"
                , spellcheck = False
                }
         ]
            ++ errorEls
            ++ [ Element.row
                    [ Element.width Element.fill
                    , Element.Font.size 16
                    ]
                    [ submitButtonOrMsg
                    , backButton
                    ]
               ]
        )


maybeUserBalanceBlock : DisplayProfile -> Wallet.State -> Maybe UserStateInfo -> Element Msg
maybeUserBalanceBlock dProfile wallet maybeExtraUserInfo =
    case ( Wallet.userInfo wallet, maybeExtraUserInfo ) of
        ( Nothing, _ ) ->
            Element.none

        ( _, Nothing ) ->
            loadingElement

        ( Just userInfo, Just extraUserInfo ) ->
            sidepaneBlockContainer
                dProfile
                PassiveStyle
                [ bigNumberElement
                    dProfile
                    [ Element.centerX ]
                    (TokenNum extraUserInfo.exitingTokenBalance)
                    Config.exitingTokenCurrencyLabel
                    PassiveStyle
                , Element.paragraph
                    ([ Element.centerX
                     , Element.width Element.shrink
                     ]
                        ++ (case dProfile of
                                Desktop ->
                                    []

                                SmallDesktop ->
                                    [ Element.Font.size 10 ]
                           )
                    )
                    [ Element.text "in your wallet"
                    ]
                , if TokenValue.isZero extraUserInfo.exitingTokenBalance then
                    Element.none

                  else
                    Element.paragraph
                        ([ Element.centerX
                         , Element.width Element.shrink
                         , Element.Font.color EH.lightBlue
                         , Element.pointer
                         , Element.Events.onClick AddFryToMetaMaskClicked
                         , EH.withTitle <| "Add " ++ Config.exitingTokenCurrencyLabel ++ " to Metamask or another EIP 747 compliant Web3 wallet"
                         ]
                            ++ (case dProfile of
                                    Desktop ->
                                        []

                                    SmallDesktop ->
                                        [ Element.Font.size 10 ]
                               )
                        )
                        [ Element.text <| "List " ++ Config.exitingTokenCurrencyLabel ++ " in your wallet"
                        ]
                ]


maybeClaimBlock : DisplayProfile -> Wallet.State -> Maybe ExitInfo -> Element Msg
maybeClaimBlock dProfile wallet maybeExitInfo =
    case ( Wallet.userInfo wallet, maybeExitInfo ) of
        ( Nothing, _ ) ->
            Element.none

        ( _, Nothing ) ->
            loadingElement

        ( Just userInfo, Just exitInfo ) ->
            let
                ( blockStyle, maybeClaimButton, exitableValue ) =
                    if TokenValue.isZero exitInfo.totalExitable then
                        ( PassiveStyle, Nothing, TokenValue.zero )

                    else
                        ( ActiveStyle
                        , Just <|
                            makeClaimButton
                                dProfile
                                userInfo
                                exitInfo
                        , exitInfo.totalExitable
                        )
            in
            if dProfile == SmallDesktop && exitableValue == TokenValue.zero then
                Element.none

            else
                sidepaneBlockContainer
                    dProfile
                    blockStyle
                    (case dProfile of
                        Desktop ->
                            [ bigNumberElement
                                dProfile
                                [ Element.centerX ]
                                (TokenNum exitInfo.totalExitable)
                                Config.exitingTokenCurrencyLabel
                                blockStyle
                            , Element.paragraph
                                ([ Element.centerX
                                 , Element.width Element.shrink
                                 ]
                                    ++ (case dProfile of
                                            Desktop ->
                                                []

                                            SmallDesktop ->
                                                [ Element.Font.size 10 ]
                                       )
                                )
                                [ Element.text "available for "
                                , emphasizedText blockStyle "you"
                                , Element.text " to claim"
                                ]
                            , Maybe.map
                                (Element.el [ Element.centerX ])
                                maybeClaimButton
                                |> Maybe.withDefault Element.none
                            ]

                        SmallDesktop ->
                            [ Element.row [ Element.width Element.fill, Element.spacing 5 ]
                                [ bigNumberElement
                                    dProfile
                                    [ Element.centerX ]
                                    (TokenNum exitInfo.totalExitable)
                                    Config.exitingTokenCurrencyLabel
                                    blockStyle
                                , Element.paragraph
                                    ([ Element.centerX
                                     , Element.width Element.shrink
                                     ]
                                        ++ (case dProfile of
                                                Desktop ->
                                                    []

                                                SmallDesktop ->
                                                    [ Element.Font.size 10 ]
                                           )
                                    )
                                    [ Element.text "available for "
                                    , emphasizedText blockStyle "you"
                                    , Element.text " to claim"
                                    ]
                                , Maybe.map
                                    (Element.el [ Element.centerX ])
                                    maybeClaimButton
                                    |> Maybe.withDefault Element.none
                                ]
                            ]
                    )


totalExitedBlock : DisplayProfile -> Maybe TokenValue -> Element Msg
totalExitedBlock dProfile maybeTotalExited =
    case maybeTotalExited of
        Nothing ->
            loadingElement

        Just totalExited ->
            sidepaneBlockContainer
                dProfile
                PassiveStyle
                [ bigNumberElement
                    dProfile
                    [ Element.centerX ]
                    (TokenNum totalExited)
                    Config.exitingTokenCurrencyLabel
                    PassiveStyle
                , Element.paragraph
                    [ Element.centerX
                    , Element.width Element.shrink
                    ]
                    [ Element.text "disbursed "
                    , emphasizedText PassiveStyle "in total"
                    ]
                ]


focusedBucketHeaderEl :
    DisplayProfile
    -> Int
    -> Int
    -> Maybe UserInfo
    -> Maybe Address
    -> Bool
    -> SaleType
    -> TestMode
    -> Element Msg
focusedBucketHeaderEl dProfile bucketId currentBucketId maybeUserInfo maybeReferrer referralModalActive saleType testMode =
    Element.column
        [ Element.width Element.fill ]
        [ maybeReferralIndicatorAndModal
            dProfile
            maybeUserInfo
            maybeReferrer
            referralModalActive
            saleType
            testMode
        , Element.row
            [ Element.Font.size (responsiveVal dProfile 30 16)
            , Element.Font.bold
            , Element.alignLeft
            , Element.spacing (responsiveVal dProfile 10 4)
            , Element.centerX
            ]
            [ prevTenBucketArrow bucketId
            , prevBucketArrow bucketId
            , Element.column
                [ Element.width Element.fill
                , Element.centerX
                ]
                [ Element.row
                    [ Element.centerX
                    ]
                    [ Element.text <|
                        "Bucket #"
                            ++ String.fromInt bucketId
                    ]
                , case dProfile of
                    Desktop ->
                        Element.none

                    SmallDesktop ->
                        Element.row
                            [ Element.centerX
                            ]
                            [ if currentBucketId /= bucketId then
                                jumpToCurrentBucketButton
                                    dProfile
                                    currentBucketId

                              else
                                Element.none
                            ]
                ]
            , nextBucketArrow bucketId
            , nextTenBucketArrow bucketId
            ]
        , case dProfile of
            Desktop ->
                Element.row
                    [ Element.centerX
                    ]
                    [ if currentBucketId /= bucketId then
                        jumpToCurrentBucketButton
                            dProfile
                            currentBucketId

                      else
                        Element.none
                    ]

            SmallDesktop ->
                Element.none
        ]


edges =
    { top = 0
    , right = 0
    , bottom = 0
    , left = 0
    }


maybeReferralIndicatorAndModal :
    DisplayProfile
    -> Maybe UserInfo
    -> Maybe Address
    -> Bool
    -> SaleType
    -> TestMode
    -> Element Msg
maybeReferralIndicatorAndModal dProfile maybeUserInfo maybeReferrer referralModalActive saleType testMode =
    case maybeUserInfo of
        Nothing ->
            Element.none

        Just userInfo ->
            let
                maybeModalAttribute =
                    responsiveVal
                        dProfile
                        Element.onRight
                        Element.below
                    <|
                        if referralModalActive then
                            Element.el
                                [ Element.centerX
                                , Element.moveRight <| responsiveVal dProfile 25 0
                                , Element.moveUp (responsiveVal dProfile 50 0)
                                , EH.moveToFront
                                ]
                                (referralModal dProfile userInfo maybeReferrer testMode)

                        else
                            Element.none
            in
            Element.row
                [ Element.width Element.fill
                , Element.height Element.fill
                , Element.centerX
                , Element.centerY
                , Element.spacing 10
                , Element.paddingEach { edges | bottom = 10 }
                ]
                [ Element.el
                    [ Element.centerX

                    --, Element.paddingEach { edges | bottom = 10 }
                    , maybeModalAttribute
                    , Element.inFront <|
                        if referralModalActive then
                            Element.el
                                [ EH.moveToFront ]
                            <|
                                referralBonusIndicator
                                    dProfile
                                    maybeReferrer
                                    True

                        else
                            Element.none
                    ]
                  <|
                    referralBonusIndicator
                        dProfile
                        maybeReferrer
                        referralModalActive
                , saleTypeBlock
                    dProfile
                    saleType
                ]


focusedBucketSubheaderEl : DisplayProfile -> ValidBucketInfo -> Element Msg
focusedBucketSubheaderEl dProfile bucketInfo =
    let
        bidText =
            case bucketInfo.state of
                _ ->
                    " has been bid on this bucket so far. All bids are irreversible."
    in
    case bucketInfo.bucketData.totalValueEntered of
        Just totalValueEntered ->
            Element.paragraph
                [ Element.Font.color grayTextColor
                , Element.Font.size (responsiveVal dProfile 15 7)
                ]
                (case dProfile of
                    SmallDesktop ->
                        [ Element.none ]

                    Desktop ->
                        [ emphasizedText PassiveStyle <|
                            TokenValue.toConciseString totalValueEntered
                        , Element.text <|
                            " "
                                ++ Config.enteringTokenCurrencyLabel
                                ++ bidText
                        ]
                )

        _ ->
            loadingElement


navigateElementDetail : Int -> Image -> Element Msg
navigateElementDetail bucketToFocusOn image =
    Images.toElement
        [ Element.pointer
        , Element.Events.onClick (FocusToBucket bucketToFocusOn)
        , Element.Font.extraBold
        , EH.noSelectText
        , Element.width <| Element.px 30
        ]
        image


nextBucketArrow : Int -> Element Msg
nextBucketArrow currentBucketId =
    navigateElementDetail (currentBucketId + 1) Images.right


prevBucketArrow : Int -> Element Msg
prevBucketArrow currentBucketId =
    navigateElementDetail (currentBucketId - 1) Images.left


prevTenBucketArrow : Int -> Element Msg
prevTenBucketArrow currentBucketId =
    navigateElementDetail (currentBucketId - 10) Images.leftTen


nextTenBucketArrow : Int -> Element Msg
nextTenBucketArrow currentBucketId =
    navigateElementDetail (currentBucketId + 10) Images.rightTen


focusedBucketTimeLeftEl : DisplayProfile -> RelevantTimingInfo -> TestMode -> Element Msg
focusedBucketTimeLeftEl dProfile timingInfo testMode =
    Element.row
        [ Element.width Element.fill
        , Element.spacing 22
        ]
        [ progressBarElement (Element.rgba255 235 237 243 0.6) <|
            case timingInfo.state of
                Current ->
                    [ ( 1
                            - ((Time.posixToMillis timingInfo.relevantTimeFromNow |> toFloat)
                                / (Time.posixToMillis (Config.bucketSaleBucketInterval testMode) |> toFloat)
                              )
                      , Element.rgb255 255 0 120
                      )
                    ]

                _ ->
                    []
        , let
            intervalString =
                TimeHelpers.toConciseIntervalString timingInfo.relevantTimeFromNow
          in
          (Element.el
            (case dProfile of
                Desktop ->
                    [ Element.Font.color deepBlue ]

                SmallDesktop ->
                    [ Element.Font.color deepBlue
                    , Element.Font.size 12
                    ]
            )
            << Element.text
          )
            (case timingInfo.state of
                Closed ->
                    "ended " ++ intervalString ++ " ago"

                Current ->
                    intervalString ++ " left"

                Future ->
                    "starts in " ++ intervalString
            )
        ]


bucketUX :
    DisplayProfile
    -> Wallet.State
    -> Maybe Address
    -> Maybe UserStateInfo
    -> EnterUXModel
    -> ValidBucketInfo
    -> JurisdictionCheckStatus
    -> List TrackedTx
    -> SaleType
    -> TestMode
    -> Element Msg
bucketUX dProfile wallet maybeReferrer maybeExtraUserInfo enterUXModel bucketInfo jurisdictionCheckStatus trackedTxs saleType testMode =
    let
        miningEnters =
            trackedTxs
                |> List.filterMap
                    (\trackedTx ->
                        case ( trackedTx.action, trackedTx.status ) of
                            ( Enter enterInfo, Signed _ Mining ) ->
                                if enterInfo.bucketId == bucketInfo.id then
                                    Just enterInfo

                                else
                                    Nothing

                            _ ->
                                Nothing
                    )

        unlockMining =
            trackedTxs
                |> List.any
                    (\trackedTx ->
                        case trackedTx.action of
                            Unlock ->
                                case trackedTx.status of
                                    Signed _ Mining ->
                                        True

                                    _ ->
                                        False

                            _ ->
                                False
                    )
    in
    Element.column
        [ Element.width Element.fill
        , Element.spacing 20
        ]
        ([]
            ++ (case dProfile of
                    Desktop ->
                        [ bidInputBlock
                            dProfile
                            enterUXModel
                            bucketInfo
                            saleType
                            testMode
                        , actionButton
                            dProfile
                            jurisdictionCheckStatus
                            maybeReferrer
                            wallet
                            maybeExtraUserInfo
                            unlockMining
                            enterUXModel
                            bucketInfo
                            trackedTxs
                            saleType
                            testMode
                        , bidImpactBlock
                            dProfile
                            enterUXModel
                            bucketInfo
                            miningEnters
                            testMode
                        , otherBidsImpactMsg
                            dProfile
                        ]

                    SmallDesktop ->
                        [ Element.column
                            [ Element.width <| Element.fillPortion 3
                            , Element.spacingXY 0 3
                            ]
                            [ maybeClaimBlock
                                dProfile
                                wallet
                                (maybeExtraUserInfo |> Maybe.map .exitInfo)
                            , Element.el
                                [ Element.width Element.fill
                                , Element.alignTop
                                ]
                              <|
                                bidInputBlock
                                    dProfile
                                    enterUXModel
                                    bucketInfo
                                    saleType
                                    testMode
                            , actionButton
                                dProfile
                                jurisdictionCheckStatus
                                maybeReferrer
                                wallet
                                maybeExtraUserInfo
                                unlockMining
                                enterUXModel
                                bucketInfo
                                trackedTxs
                                saleType
                                testMode
                            , bidImpactBlock
                                dProfile
                                enterUXModel
                                bucketInfo
                                miningEnters
                                testMode
                            , otherBidsImpactMsg
                                dProfile
                            ]
                        ]
               )
        )


bidInputBlock :
    DisplayProfile
    -> EnterUXModel
    -> ValidBucketInfo
    -> SaleType
    -> TestMode
    -> Element Msg
bidInputBlock dProfile enterUXModel bucketInfo saleType testMode =
    centerpaneBlockContainer
        dProfile
        ActiveStyle
        []
    <|
        case dProfile of
            Desktop ->
                [ emphasizedText ActiveStyle "I want to bid:"
                , Element.row
                    [ Element.Background.color <| Element.rgba 1 1 1 0.08
                    , Element.Border.rounded 4
                    , Element.padding <|
                        responsiveVal dProfile 13 7
                    , Element.width Element.fill
                    ]
                    [ Element.Input.text
                        [ Element.Font.size 19
                        , Element.Font.medium
                        , Element.Font.color EH.white
                        , Element.Border.width 0
                        , Element.width Element.fill
                        , Element.Background.color EH.transparent
                        ]
                        { onChange = EnterInputChanged
                        , text = enterUXModel.input
                        , placeholder =
                            Just <|
                                Element.Input.placeholder
                                    [ Element.Font.medium
                                    , Element.Font.color <| Element.rgba 1 1 1 0.25
                                    ]
                                    (Element.text "Enter Amount")
                        , label = Element.Input.labelHidden "bid amount"
                        }
                    , Element.row
                        [ Element.centerY
                        , Element.spacing 10
                        ]
                        [ Images.enteringTokenSymbol
                            |> Images.toElement [ Element.height <| Element.px 30 ]
                        , Element.text Config.enteringTokenCurrencyLabel
                        ]
                    ]
                , if saleType == Standard then
                    Maybe.map
                        (\totalValueEntered ->
                            pricePerTokenMsg
                                dProfile
                                totalValueEntered
                                (enterUXModel.amount
                                    |> Maybe.map Result.toMaybe
                                    |> Maybe.Extra.join
                                )
                                testMode
                        )
                        bucketInfo.bucketData.totalValueEntered
                        |> Maybe.withDefault loadingElement

                  else
                    Element.none
                ]

            SmallDesktop ->
                let
                    totalValueEntered =
                        case bucketInfo.bucketData.totalValueEntered of
                            Just totalEntered ->
                                totalEntered

                            _ ->
                                TokenValue.zero
                in
                [ Element.row
                    [ Element.width Element.fill ]
                    [ emphasizedText ActiveStyle <| "I want to bid:"
                    , Element.column
                        [ Element.width Element.fill ]
                        [ Element.row
                            [ Element.alignRight ]
                            [ emphasizedText
                                ActiveStyle
                              <|
                                TokenValue.toConciseString
                                    totalValueEntered
                                    ++ " "
                                    ++ Config.enteringTokenCurrencyLabel
                                    ++ " already bid"
                            ]
                        ]
                    ]
                , Element.row
                    [ Element.Background.color <|
                        Element.rgba 1 1 1 0.08
                    , Element.Border.rounded 4
                    , Element.padding 4
                    , Element.width Element.fill
                    ]
                    [ Element.Input.text
                        [ Element.Font.size 12
                        , Element.Font.medium
                        , Element.Font.color EH.white
                        , Element.Border.width 0
                        , Element.width Element.fill
                        , Element.Background.color EH.transparent
                        ]
                        { onChange = EnterInputChanged
                        , text = enterUXModel.input
                        , placeholder =
                            Just <|
                                Element.Input.placeholder
                                    [ Element.Font.medium
                                    , Element.Font.color <|
                                        Element.rgba 1 1 1 0.25
                                    ]
                                    (Element.text "Enter Amount")
                        , label = Element.Input.labelHidden "bid amount"
                        }
                    , Element.row
                        [ Element.centerY
                        , Element.spacing 8
                        ]
                        [ Images.enteringTokenSymbol
                            |> Images.toElement [ Element.height <| Element.px 20 ]
                        , Element.text Config.enteringTokenCurrencyLabel
                        ]
                    ]
                , Maybe.map
                    (\totalValue ->
                        pricePerTokenMsg
                            dProfile
                            totalValue
                            (enterUXModel.amount
                                |> Maybe.map Result.toMaybe
                                |> Maybe.Extra.join
                            )
                            testMode
                    )
                    bucketInfo.bucketData.totalValueEntered
                    |> Maybe.withDefault loadingElement
                ]


pricePerTokenMsg : DisplayProfile -> TokenValue -> Maybe TokenValue -> TestMode -> Element Msg
pricePerTokenMsg dProfile totalValueEntered maybeEnterAmount testMode =
    case dProfile of
        Desktop ->
            Element.paragraph
                [ Element.Font.size 14
                , Element.Font.medium
                ]
                ([ Element.text <|
                    "The current "
                        ++ Config.exitingTokenCurrencyLabel
                        ++ " price is "
                        ++ (calcEffectivePricePerToken
                                totalValueEntered
                                testMode
                                |> TokenValue.toConciseString
                           )
                        ++ " "
                        ++ Config.enteringTokenCurrencyLabel
                        ++ "/"
                        ++ Config.exitingTokenCurrencyLabel
                        ++ "."
                 ]
                    ++ (case maybeEnterAmount of
                            Just amount ->
                                [ Element.text " This bid will increase the price to "
                                , emphasizedText ActiveStyle <|
                                    (calcEffectivePricePerToken
                                        (TokenValue.add
                                            totalValueEntered
                                            amount
                                        )
                                        testMode
                                        |> TokenValue.toConciseString
                                    )
                                        ++ " "
                                        ++ Config.enteringTokenCurrencyLabel
                                        ++ "/"
                                        ++ Config.exitingTokenCurrencyLabel
                                        ++ "."
                                ]

                            _ ->
                                []
                       )
                )

        SmallDesktop ->
            let
                listEl =
                    Element.el [ Element.paddingXY 0 3 ]
            in
            Element.column
                [ Element.Font.size 10
                , Element.Font.medium
                ]
                ([ listEl
                    (Element.text <|
                        "Current price: "
                            ++ (calcEffectivePricePerToken
                                    totalValueEntered
                                    testMode
                                    |> TokenValue.toConciseString
                               )
                            ++ " "
                            ++ Config.enteringTokenCurrencyLabel
                            ++ "/"
                            ++ Config.exitingTokenCurrencyLabel
                            ++ "."
                    )
                 ]
                    ++ (case maybeEnterAmount of
                            Just amount ->
                                [ listEl
                                    (Element.text <|
                                        "After this bid: "
                                            ++ (calcEffectivePricePerToken
                                                    (TokenValue.add
                                                        totalValueEntered
                                                        amount
                                                    )
                                                    testMode
                                                    |> TokenValue.toConciseString
                                               )
                                            ++ " "
                                            ++ Config.enteringTokenCurrencyLabel
                                            ++ "/"
                                            ++ Config.exitingTokenCurrencyLabel
                                            ++ "."
                                    )
                                ]

                            _ ->
                                []
                       )
                )


bidImpactBlock :
    DisplayProfile
    -> EnterUXModel
    -> ValidBucketInfo
    -> List EnterInfo
    -> TestMode
    -> Element Msg
bidImpactBlock dProfile enterUXModel bucketInfo miningEnters testMode =
    centerpaneBlockContainer
        dProfile
        PassiveStyle
        []
    <|
        [ emphasizedText PassiveStyle "Your current bid standing:" ]
            ++ (case ( bucketInfo.bucketData.totalValueEntered, bucketInfo.bucketData.userBuy ) of
                    ( Just totalValueEntered, Just userBuy ) ->
                        let
                            existingUserBidAmount =
                                userBuy.valueEntered

                            miningUserBidAmount =
                                miningEnters
                                    |> List.map .amount
                                    |> List.foldl TokenValue.add TokenValue.zero

                            extraUserBidAmount =
                                enterUXModel.amount
                                    |> Maybe.map Result.toMaybe
                                    |> Maybe.Extra.join
                                    |> Maybe.withDefault TokenValue.zero
                        in
                        [ bidImpactParagraphEl totalValueEntered ( existingUserBidAmount, miningUserBidAmount, extraUserBidAmount ) testMode
                        , bidBarEl totalValueEntered ( existingUserBidAmount, miningUserBidAmount, extraUserBidAmount ) testMode
                        ]

                    _ ->
                        [ loadingElement ]
               )


bidImpactParagraphEl :
    TokenValue
    -> ( TokenValue, TokenValue, TokenValue )
    -> TestMode
    -> Element Msg
bidImpactParagraphEl totalValueEntered ( existingUserBidAmount, miningUserBidAmount, extraUserBidAmount ) testMode =
    let
        totalUserBidAmount =
            existingUserBidAmount
                |> TokenValue.add miningUserBidAmount
                |> TokenValue.add extraUserBidAmount

        para =
            Element.paragraph
                [ Element.width Element.fill
                , Element.Font.color grayTextColor
                ]

        existingUserBidsPara =
            para <|
                if TokenValue.isZero existingUserBidAmount then
                    [ Element.text "You haven't entered any bids into this bucket." ]

                else
                    [ Element.text "You have entered "
                    , emphasizedText PassiveStyle <|
                        TokenValue.toConciseString existingUserBidAmount
                            ++ " "
                            ++ Config.enteringTokenCurrencyLabel
                            ++ ""
                    , Element.text " into this bucket."
                    ]

        assumptionsBlock =
            let
                assumptionParasList =
                    [ if TokenValue.isZero miningUserBidAmount then
                        Nothing

                      else
                        Just <|
                            para <|
                                [ Element.text "your submitted bid of "
                                , emphasizedText PassiveStyle <|
                                    TokenValue.toConciseString miningUserBidAmount
                                        ++ " "
                                        ++ Config.enteringTokenCurrencyLabel
                                        ++ ""
                                , Element.text " is mined before this bucket ends"
                                ]
                    , if TokenValue.isZero extraUserBidAmount then
                        Nothing

                      else
                        Just <|
                            para <|
                                [ Element.text "you submit a further bid of "
                                , emphasizedText PassiveStyle <|
                                    TokenValue.toConciseString extraUserBidAmount
                                        ++ " "
                                        ++ Config.enteringTokenCurrencyLabel
                                        ++ ""
                                ]
                    ]
                        |> Maybe.Extra.values
            in
            if assumptionParasList == [] then
                Element.none

            else
                Element.column
                    [ Element.width Element.fill
                    , Element.spacing 5
                    ]
                    ([ para <|
                        [ Element.text "Assuming:" ]
                     ]
                        ++ (assumptionParasList
                                |> List.map
                                    (\p ->
                                        Element.row
                                            [ Element.width Element.fill
                                            , Element.spacing 10
                                            ]
                                            [ Element.text EH.bulletPointString
                                            , p
                                            ]
                                    )
                           )
                    )

        claimablePara =
            if TokenValue.isZero totalUserBidAmount then
                Element.none

            else
                para <|
                    [ Element.text "If no one else bids on this bucket before it ends, you will be able to claim "
                    , emphasizedText PassiveStyle <|
                        (calcClaimableTokens
                            (totalValueEntered
                                |> TokenValue.add miningUserBidAmount
                                |> TokenValue.add extraUserBidAmount
                            )
                            totalUserBidAmount
                            testMode
                            |> TokenValue.toConciseString
                        )
                            ++ " "
                            ++ Config.exitingTokenCurrencyLabel
                            ++ ""
                    , Element.text <|
                        " out of "
                            ++ TokenValue.toConciseString (Config.bucketSaleTokensPerBucket testMode)
                            ++ " "
                            ++ Config.exitingTokenCurrencyLabel
                            ++ " available."
                    ]
    in
    Element.column
        [ Element.width Element.fill
        , Element.spacing 10
        ]
    <|
        [ existingUserBidsPara
        , assumptionsBlock
        , claimablePara
        ]


bidBarEl :
    TokenValue
    -> ( TokenValue, TokenValue, TokenValue )
    -> TestMode
    -> Element Msg
bidBarEl totalValueEntered ( existingUserBidAmount, miningUserBidAmount, extraUserBidAmount ) testMode =
    let
        totalValueEnteredAfterBidAndMining =
            totalValueEntered
                |> TokenValue.add miningUserBidAmount
                |> TokenValue.add extraUserBidAmount
    in
    if TokenValue.isZero totalValueEnteredAfterBidAndMining then
        Element.paragraph
            [ Element.width Element.fill
            , Element.Font.color grayTextColor
            ]
            [ Element.text "No one has entered any bids into this bucket yet." ]

    else
        let
            existingUserBidColor =
                deepBlue

            miningUserBidColor =
                purple

            extraUserBidColor =
                lightBlue
        in
        Element.column
            [ Element.width Element.fill
            , Element.spacing 10
            , Element.paddingXY 0 10
            ]
            [ Element.row
                [ Element.width Element.fill ]
                [ Element.column
                    [ Element.alignLeft
                    , Element.spacing 6
                    ]
                    [ Element.el [ Element.Font.color grayTextColor ] <| Element.text "Your bid"
                    , Element.row []
                        (([ ( existingUserBidAmount, existingUserBidColor )
                          , ( miningUserBidAmount, miningUserBidColor )
                          , ( extraUserBidAmount, extraUserBidColor )
                          ]
                            |> List.map
                                (\( t, color ) ->
                                    if TokenValue.isZero t then
                                        Nothing

                                    else
                                        Just ( t, color )
                                )
                            |> Maybe.Extra.values
                            |> List.map
                                (\( tokens, color ) ->
                                    Element.el
                                        [ Element.Font.color color ]
                                        (Element.text <| TokenValue.toConciseString tokens)
                                )
                            |> List.intersperse (Element.text " + ")
                         )
                            |> (\els ->
                                    if List.length els > 0 then
                                        els ++ [ Element.text (" " ++ Config.enteringTokenCurrencyLabel) ]

                                    else
                                        [ Element.text <| "0 " ++ Config.enteringTokenCurrencyLabel ]
                               )
                        )
                    ]
                , Element.column
                    [ Element.alignRight
                    , Element.spacing 6
                    ]
                    [ Element.paragraph
                        [ Element.Font.color grayTextColor
                        , Element.alignRight
                        ]
                        [ Element.text <|
                            if totalValueEntered /= totalValueEnteredAfterBidAndMining then
                                "Resulting total bids in bucket"

                            else
                                "Total bids in bucket"
                        ]
                    , Element.el
                        [ Element.alignRight ]
                        (Element.text <|
                            TokenValue.toConciseString totalValueEnteredAfterBidAndMining
                                ++ " "
                                ++ Config.enteringTokenCurrencyLabel
                                ++ ""
                        )
                    ]
                ]
            , progressBarElement (Element.rgba 0 0 0 0.1)
                [ ( TokenValue.toFloatWithWarning existingUserBidAmount
                        / TokenValue.toFloatWithWarning totalValueEnteredAfterBidAndMining
                  , existingUserBidColor
                  )
                , ( TokenValue.toFloatWithWarning miningUserBidAmount
                        / TokenValue.toFloatWithWarning totalValueEnteredAfterBidAndMining
                  , miningUserBidColor
                  )
                , ( TokenValue.toFloatWithWarning extraUserBidAmount
                        / TokenValue.toFloatWithWarning totalValueEnteredAfterBidAndMining
                  , extraUserBidColor
                  )
                ]
            ]


otherBidsImpactMsg :
    DisplayProfile
    -> Element Msg
otherBidsImpactMsg dProfile =
    centerpaneBlockContainer
        dProfile
        PassiveStyle
        []
        [ emphasizedText PassiveStyle "If other bids are made:"
        , Element.paragraph
            [ Element.width Element.fill
            , Element.Font.color grayTextColor
            ]
            [ Element.text <|
                "The price per token will increase further, and the amount of "
                    ++ Config.exitingTokenCurrencyLabel
                    ++ " you can claim from the bucket will decrease proportionally. For example, if the total bid amount doubles, the effective price per token will also double, and your amount of claimable tokens will halve."
            ]
        ]


msgInsteadOfButton :
    DisplayProfile
    -> String
    -> Element.Color
    -> Element Msg
msgInsteadOfButton dProfile text color =
    Element.el
        [ Element.centerX
        , Element.Font.size <| responsiveVal dProfile 22 14
        , Element.Font.italic
        , Element.Font.color color
        ]
        (Element.text text)


verifyJurisdictionButtonOrResult :
    DisplayProfile
    -> JurisdictionCheckStatus
    -> Element Msg
verifyJurisdictionButtonOrResult dProfile jurisdictionCheckStatus =
    case jurisdictionCheckStatus of
        WaitingForClick ->
            EH.redButton
                dProfile
                [ Element.width Element.fill
                , Element.Font.size 16
                , Element.paddingXY 0 17
                , Element.spacing 3
                ]
                [ "Confirm you are not a US citizen" ]
                VerifyJurisdictionClicked

        Checking ->
            EH.disabledButton
                dProfile
                [ Element.width Element.fill ]
                "Verifying Jurisdiction..."
                Nothing

        Error errStr ->
            Element.column
                [ Element.spacing 10
                , Element.width Element.fill
                ]
                [ msgInsteadOfButton
                    dProfile
                    "Error verifying jurisdiction."
                    EH.red
                , verifyJurisdictionErrorEl
                    dProfile
                    jurisdictionCheckStatus
                    [ Element.Font.color EH.red ]
                ]

        Checked ForbiddenJurisdictions ->
            msgInsteadOfButton
                dProfile
                "Sorry, US citizens and residents are excluded."
                EH.red

        Checked JurisdictionsWeArentIntimidatedIntoExcluding ->
            msgInsteadOfButton
                dProfile
                "Jurisdiction Verified."
                green


enableTokenButton :
    DisplayProfile
    -> SaleType
    -> Element Msg
enableTokenButton dProfile saleType =
    EH.redButton
        dProfile
        [ Element.width Element.fill ]
        [ "Enable " ++ Config.enteringTokenCurrencyLabel ]
        (EnableTokenButtonClicked saleType)


disabledButton :
    DisplayProfile
    -> String
    -> Element Msg
disabledButton dProfile disableText =
    EH.disabledButton
        dProfile
        [ Element.width Element.fill ]
        disableText
        Nothing


successButton :
    DisplayProfile
    -> String
    -> Element Msg
successButton dProfile text =
    EH.disabledSuccessButton
        dProfile
        [ Element.width Element.fill ]
        text
        Nothing


continueButton :
    DisplayProfile
    -> UserInfo
    -> Int
    -> TokenValue
    -> Maybe Address
    -> TokenValue
    -> TokenValue
    -> Int
    -> SaleType
    -> Element Msg
continueButton dProfile userInfo bucketId enterAmount referrer minedTotal miningTotal nrBuckets saleType =
    let
        maybeMining =
            if miningTotal == TokenValue.zero then
                Nothing

            else
                Just <| TokenValue.toFloatString (Just 2) miningTotal ++ " " ++ Config.enteringTokenCurrencyLabel ++ " currently mining"

        maybeMined =
            if minedTotal == TokenValue.zero then
                Nothing

            else
                Just <| TokenValue.toFloatString (Just 2) minedTotal ++ " " ++ Config.enteringTokenCurrencyLabel ++ " already entered"

        maybeAlreadyEnteredString =
            case ( maybeMining, maybeMined ) of
                ( Nothing, Nothing ) ->
                    Nothing

                ( Just mining, Nothing ) ->
                    Just mining

                ( Nothing, Just mined ) ->
                    Just mined

                ( Just mining, Just mined ) ->
                    Just <|
                        mined
                            ++ " and "
                            ++ mining

        alreadyEnteredWithDescription =
            case maybeAlreadyEnteredString of
                Just alreadyEnteredString ->
                    "(You have "
                        ++ alreadyEnteredString
                        ++ ")"

                Nothing ->
                    ""
    in
    EH.redButton
        dProfile
        ([ Element.width Element.fill ]
            ++ (case dProfile of
                    Desktop ->
                        []

                    SmallDesktop ->
                        [ Element.padding 10 ]
               )
        )
        [ case saleType of
            Standard ->
                "Enter with "
                    ++ TokenValue.toFloatString (Just 2) enterAmount
                    ++ " "
                    ++ Config.enteringTokenCurrencyLabel
                    ++ " "
                    ++ alreadyEnteredWithDescription

            Advanced ->
                "Enter "
                    ++ String.fromInt nrBuckets
                    ++ " buckets with "
                    ++ TokenValue.toFloatString (Just 2) enterAmount
                    ++ " "
                    ++ Config.enteringTokenCurrencyLabel
                    ++ " at "
                    ++ String.fromFloat (TokenValue.toFloatWithWarning enterAmount / toFloat nrBuckets)
                    ++ Config.enteringTokenCurrencyLabel
                    ++ " per bucket"
        ]
        (EnterButtonClicked <|
            EnterInfo
                userInfo
                bucketId
                enterAmount
                referrer
                nrBuckets
                saleType
        )


alreadyEnteredBucketButton enterAmount =
    Element.none


actionButton :
    DisplayProfile
    -> JurisdictionCheckStatus
    -> Maybe Address
    -> Wallet.State
    -> Maybe UserStateInfo
    -> Bool
    -> EnterUXModel
    -> ValidBucketInfo
    -> List TrackedTx
    -> SaleType
    -> TestMode
    -> Element Msg
actionButton dProfile jurisdictionCheckStatus maybeReferrer wallet maybeExtraUserInfo unlockMining enterUXModel bucketInfo trackedTxs saleType testMode =
    case Wallet.userInfo wallet of
        Nothing ->
            connectToWeb3Button
                dProfile
                wallet

        Just userInfo ->
            case jurisdictionCheckStatus of
                Checked JurisdictionsWeArentIntimidatedIntoExcluding ->
                    case maybeExtraUserInfo of
                        Nothing ->
                            msgInsteadOfButton
                                dProfile
                                "Fetching user balance info..."
                                grayTextColor

                        Just extraUserInfo ->
                            if unlockMining then
                                msgInsteadOfButton
                                    dProfile
                                    "Mining token enable..."
                                    grayTextColor

                            else if TokenValue.isZero extraUserInfo.ethBalance then
                                msgInsteadOfButton
                                    dProfile
                                    "You have no Ethereum in your wallet..."
                                    orangeWarningColor

                            else if TokenValue.isZero extraUserInfo.enteringTokenAllowance then
                                enableTokenButton
                                    dProfile
                                    saleType

                            else
                                let
                                    trackedEnterTxForBucket =
                                        trackedTxs
                                            |> List.filter
                                                (\tx ->
                                                    case tx.action of
                                                        Enter enterInfo ->
                                                            enterInfo.bucketId == bucketInfo.id

                                                        _ ->
                                                            False
                                                )

                                    miningTotalForThisBucket =
                                        trackedEnterTxForBucket
                                            |> List.filter
                                                (\tx ->
                                                    case tx.status of
                                                        Signed _ Mining ->
                                                            True

                                                        _ ->
                                                            False
                                                )
                                            |> List.map
                                                (\tx ->
                                                    case tx.action of
                                                        Enter enterInfo ->
                                                            enterInfo.amount

                                                        _ ->
                                                            TokenValue.zero
                                                )
                                            |> List.foldl TokenValue.add TokenValue.zero

                                    lastTransactionsForThisBucketWasSuccessful =
                                        trackedEnterTxForBucket
                                            |> List.map
                                                (\tx ->
                                                    case tx.status of
                                                        Signed _ Success ->
                                                            True

                                                        _ ->
                                                            False
                                                )
                                            |> lastElem
                                            |> Maybe.withDefault False

                                    enteredIntoThisBucket =
                                        bucketInfo.bucketData.userBuy
                                            |> Maybe.map .valueEntered
                                            |> Maybe.withDefault TokenValue.zero

                                    nrBuckets =
                                        enterUXModel.nrBucketsInt
                                            |> Maybe.map Result.toMaybe
                                            |> Maybe.Extra.join
                                            |> Maybe.withDefault 1

                                    enterAmountSection =
                                        case enterUXModel.amount of
                                            Just (Ok enterAmount) ->
                                                if List.any (\tx -> tx.status == Signing) trackedTxs then
                                                    disabledButton
                                                        dProfile
                                                        "Sign or reject pending transactions to continue"

                                                else if TokenValue.compare enterAmount extraUserInfo.enteringTokenAllowance /= GT && TokenValue.compare enterAmount extraUserInfo.enteringTokenBalance /= LT then
                                                    disabledButton
                                                        dProfile
                                                        ("You only have "
                                                            ++ toConciseString extraUserInfo.enteringTokenBalance
                                                            ++ " "
                                                            ++ Config.enteringTokenCurrencyLabel
                                                            ++ ""
                                                        )

                                                else if TokenValue.compare enterAmount extraUserInfo.enteringTokenBalance /= GT then
                                                    continueButton
                                                        dProfile
                                                        userInfo
                                                        bucketInfo.id
                                                        enterAmount
                                                        maybeReferrer
                                                        enteredIntoThisBucket
                                                        miningTotalForThisBucket
                                                        nrBuckets
                                                        saleType

                                                else
                                                    enableTokenButton
                                                        dProfile
                                                        saleType

                                            _ ->
                                                if lastTransactionsForThisBucketWasSuccessful then
                                                    successButton
                                                        dProfile
                                                        "Successfully entered!"

                                                else
                                                    disabledButton
                                                        dProfile
                                                        "Enter bid amount to continue"
                                in
                                -- Allowance is loaded and nonzero, and we are not mining an Unlock
                                case saleType of
                                    Standard ->
                                        enterAmountSection

                                    Advanced ->
                                        let
                                            infoText =
                                                "Enter values above to continue."
                                        in
                                        case enterUXModel.fromBucketId of
                                            Just (Ok startBucketId) ->
                                                case enterUXModel.nrBucketsInt of
                                                    Just (Ok numberOfBuckets) ->
                                                        enterAmountSection

                                                    Just (Err error) ->
                                                        disabledButton
                                                            dProfile
                                                            error

                                                    Nothing ->
                                                        disabledButton
                                                            dProfile
                                                            infoText

                                            Just (Err error) ->
                                                disabledButton
                                                    dProfile
                                                    error

                                            Nothing ->
                                                disabledButton
                                                    dProfile
                                                    infoText

                _ ->
                    verifyJurisdictionButtonOrResult
                        dProfile
                        jurisdictionCheckStatus


lastElem :
    List a
    -> Maybe a
lastElem =
    List.foldl (Just >> always) Nothing


noBucketsLeftBlock : Element Msg
noBucketsLeftBlock =
    Element.text "There are no more future blocks."


maybeBucketsLeftBlock :
    DisplayProfile
    -> BucketSale
    -> Time.Posix
    -> TestMode
    -> Element Msg
maybeBucketsLeftBlock dProfile bucketSale now testMode =
    let
        currentBucketId =
            getCurrentBucketId
                bucketSale
                now
                testMode
    in
    sidepaneBlockContainer
        dProfile
        PassiveStyle
        [ bigNumberElement
            dProfile
            [ Element.centerX ]
            (IntegerNum
                (Config.bucketSaleNumBuckets
                    - currentBucketId
                )
            )
            "buckets"
            PassiveStyle
        , Element.paragraph
            [ Element.centerX
            , Element.width Element.shrink
            ]
            [ Element.text "left to run" ]
        ]


maybeSoldTokenInFutureBucketsBlock :
    DisplayProfile
    -> BucketSale
    -> Time.Posix
    -> TestMode
    -> Element Msg
maybeSoldTokenInFutureBucketsBlock dProfile bucketSale now testMode =
    let
        currentBucketId =
            getCurrentBucketId
                bucketSale
                now
                testMode
    in
    sidepaneBlockContainer
        dProfile
        PassiveStyle
        [ bigNumberElement
            dProfile
            [ Element.centerX ]
            (TokenNum
                (TokenValue.mul
                    (Config.bucketSaleTokensPerBucket testMode)
                    (Config.bucketSaleNumBuckets
                        - currentBucketId
                    )
                )
            )
            Config.exitingTokenCurrencyLabel
            PassiveStyle
        , Element.paragraph
            [ Element.centerX
            , Element.width Element.shrink
            ]
            [ Element.text "left to be sold" ]
        ]


trackedTxsElement :
    List TrackedTx
    -> Element Msg
trackedTxsElement trackedTxs =
    if List.length trackedTxs == 0 then
        Element.none

    else
        Element.column
            [ Element.Border.rounded 5
            , Element.Background.color <| Element.rgb 0.9 0.9 0.9
            , Element.spacing 14
            , Element.padding 10
            , Element.width Element.fill
            ]
            [ Element.el [ Element.Font.size 20 ] <|
                Element.text "Eth Transactions"
            , trackedTxsColumn trackedTxs
            ]


trackedTxsColumn :
    List TrackedTx
    -> Element Msg
trackedTxsColumn trackedTxs =
    Element.column
        [ Element.spacing 10
        , Element.padding 5
        ]
        (List.map trackedTxRow trackedTxs)


trackedTxRow :
    TrackedTx
    -> Element Msg
trackedTxRow trackedTx =
    let
        statusEl =
            let
                ( text, bgColor, maybeEtherscanLinkEl ) =
                    case trackedTx.status of
                        Signing ->
                            ( "Awaiting Metamask Signature"
                            , Element.rgb 1 1 0.5
                            , Nothing
                            )

                        Rejected ->
                            ( "Rejected By User"
                            , Element.rgb 1 0.7 0.7
                            , Nothing
                            )

                        Signed txHash signedTxStatus ->
                            let
                                etherscanLink =
                                    Element.newTabLink
                                        []
                                        { url = "https://etherscan.io/tx/" ++ Eth.Utils.txHashToString txHash
                                        , label =
                                            Element.el
                                                [ Element.Font.color EH.lightBlue ]
                                            <|
                                                Element.text "Inspect"
                                        }
                            in
                            case signedTxStatus of
                                Mining ->
                                    ( "Mining"
                                    , Element.rgb 1 0.7 1
                                    , Just etherscanLink
                                    )

                                Success ->
                                    ( "Success"
                                    , Element.rgb 0.7 1 0.7
                                    , Just etherscanLink
                                    )

                                Failed ->
                                    ( "Failed"
                                    , Element.rgb 1 0.7 0.7
                                    , Just etherscanLink
                                    )
            in
            Element.row
                [ Element.alignLeft
                , Element.spacing 5
                , Element.Font.size 12
                ]
                [ Element.el
                    [ Element.padding 5
                    , Element.Border.rounded 4
                    , Element.Background.color <| bgColor
                    , Element.Border.width 1
                    , Element.Border.color <| Element.rgba 0 0 0 0.5
                    ]
                  <|
                    Element.text text
                , maybeEtherscanLinkEl |> Maybe.withDefault Element.none
                ]
    in
    Element.column
        [ Element.Font.color grayTextColor
        , Element.Border.width 1
        , Element.Border.color <| Element.rgb 0.8 0.8 0.8
        , Element.Background.color <| Element.rgb 0.95 0.95 0.95
        , Element.spacing 5
        , Element.padding 4
        , Element.Border.rounded 4
        ]
        [ Element.el
            [ Element.width Element.fill
            , Element.clip
            , Element.Font.bold
            , Element.Font.size 16
            ]
          <|
            Element.text <|
                makeDescription trackedTx.action
        , statusEl
        ]


makeDescription :
    ActionData
    -> String
makeDescription action =
    case action of
        Unlock ->
            "Enable " ++ Config.enteringTokenCurrencyLabel

        Enter enterInfo ->
            "Bid on bucket "
                ++ String.fromInt enterInfo.bucketId
                ++ " with "
                ++ TokenValue.toConciseString enterInfo.amount
                ++ " "
                ++ Config.enteringTokenCurrencyLabel

        Exit ->
            "Claim " ++ Config.exitingTokenCurrencyLabel ++ ""


viewModals :
    DisplayProfile
    -> Model
    -> Maybe Address
    -> List (Element Msg)
viewModals dProfile model maybeReferrer =
    Maybe.Extra.values
        [ case model.enterInfoToConfirm of
            Just enterInfo ->
                Just <|
                    EH.modal
                        (Element.rgba 0 0 0 0.25)
                        False
                        NoOp
                        CancelClicked
                    <|
                        viewAgreeToTosModal dProfile model.confirmTosModel enterInfo

            _ ->
                Nothing
        , if model.showReferralModal then
            Just <|
                EH.modal
                    (Element.rgba 0 0 0 0.25)
                    False
                    (CloseReferralModal maybeReferrer)
                    (CloseReferralModal maybeReferrer)
                    Element.none

          else
            Nothing
        ]


viewYoutubeLinksBlock :
    DisplayProfile
    -> Bool
    -> Element Msg
viewYoutubeLinksBlock dProfile showBlock =
    Element.column
        (commonPaneAttributes
            ++ [ Element.padding 20
               , Element.alignTop
               , Element.width Element.fill
               , responsiveVal
                    dProfile
                    (Element.paddingXY 32 25)
                    (Element.paddingXY 15 5)
               ]
            ++ (case dProfile of
                    Desktop ->
                        []

                    SmallDesktop ->
                        [ Element.spacing 5 ]
               )
        )
        [ blockTitleText "Not sure where to start?"
            (case dProfile of
                Desktop ->
                    []

                SmallDesktop ->
                    [ Element.Events.onClick YoutubeBlockClicked
                    , Element.Font.size 16
                    ]
            )
        , viewYoutubeLinksColumn dProfile
            showBlock
            [ ( "Foundry:", "What you're buying", "https://foundrydao.com/presentation.pdf" )
            , ( "Video 1:", "Install Metamask", "https://www.youtube.com/watch?v=HTvgY5Xac78" )
            , ( "Video 2:", "Turn ETH into DAI", "https://www.youtube.com/watch?v=gkt-Wv104RU" )
            , ( "Video 3:", "Participate in the sale", "https://www.youtube.com/watch?v=jwqAvGYsIrE" )
            , ( "Video 4:", "Claim your FRY", "https://www.youtube.com/watch?v=-7yJMku7GPs" )
            ]
        ]


viewYoutubeLinksColumn :
    DisplayProfile
    -> Bool
    -> List ( String, String, String )
    -> Element Msg
viewYoutubeLinksColumn dProfile showBlock linkInfoList =
    if dProfile == SmallDesktop && showBlock == False then
        Element.none

    else
        Element.column
            [ Element.width Element.fill
            , Element.spacing <| responsiveVal dProfile 10 5
            ]
            (linkInfoList
                |> List.map
                    (\( preTitle, title, url ) ->
                        Element.row
                            [ Element.spacing <| responsiveVal dProfile 10 5
                            ]
                            [ Element.el
                                ([ Element.Font.bold
                                 , Element.width <|
                                    Element.px <|
                                        responsiveVal dProfile 75 60
                                 ]
                                    ++ (case dProfile of
                                            Desktop ->
                                                []

                                            SmallDesktop ->
                                                [ Element.Font.size 14 ]
                                       )
                                )
                              <|
                                Element.text preTitle
                            , Element.newTabLink
                                ([ Element.Font.color EH.lightBlue
                                 ]
                                    ++ (case dProfile of
                                            Desktop ->
                                                []

                                            SmallDesktop ->
                                                [ Element.Font.size 14 ]
                                       )
                                )
                                { url = url
                                , label = Element.text title
                                }
                            ]
                    )
            )


viewAgreeToTosModal :
    DisplayProfile
    -> ConfirmTosModel
    -> EnterInfo
    -> Element Msg
viewAgreeToTosModal dProfile confirmTosModel enterInfo =
    Element.el
        [ Element.centerX
        , Element.paddingEach
            { top = responsiveVal dProfile 100 0
            , bottom = 0
            , right = 0
            , left = 0
            }
        ]
    <|
        Element.el
            ([ Element.centerX
             , Element.alignTop
             , Element.Border.rounded 10
             , Element.Border.glow
                (Element.rgba 0 0 0 0.2)
                5
             , Element.Background.color <| Element.rgb 0.7 0.8 1
             ]
                ++ (case dProfile of
                        Desktop ->
                            [ Element.width <| Element.px 700
                            , Element.height <| Element.px 800
                            , Element.padding 20
                            ]

                        SmallDesktop ->
                            [ Element.height <| Element.px 500
                            , Element.padding 5
                            ]
                   )
            )
        <|
            Element.column
                [ Element.width Element.fill
                , Element.height Element.fill
                , Element.spacing (responsiveVal dProfile 10 5)
                , Element.padding (responsiveVal dProfile 20 10)
                ]
                [ viewTosTitle dProfile confirmTosModel.page (List.length confirmTosModel.points)
                , Element.el
                    [ Element.centerY
                    , Element.width Element.fill
                    ]
                  <|
                    viewTosPage dProfile confirmTosModel
                , Element.el
                    [ Element.alignBottom
                    , Element.width Element.fill
                    ]
                  <|
                    viewTosPageNavigationButtons
                        dProfile
                        confirmTosModel
                        enterInfo
                ]


viewTosTitle :
    DisplayProfile
    -> Int
    -> Int
    -> Element Msg
viewTosTitle dProfile pageNum totalPages =
    Element.el
        [ Element.Font.size (responsiveVal dProfile 40 20)
        , Element.Font.bold
        , Element.centerX
        ]
    <|
        Element.text <|
            "Terms of Service ("
                ++ String.fromInt (pageNum + 1)
                ++ " of "
                ++ String.fromInt totalPages
                ++ ")"


viewTosPage :
    DisplayProfile
    -> ConfirmTosModel
    -> Element Msg
viewTosPage dProfile agreeToTosModel =
    let
        ( boundedPageNum, pagePoints ) =
            case List.Extra.getAt agreeToTosModel.page agreeToTosModel.points of
                Just points ->
                    ( agreeToTosModel.page
                    , points
                    )

                Nothing ->
                    ( 0
                    , List.head agreeToTosModel.points
                        |> Maybe.withDefault []
                    )
    in
    Element.column
        [ Element.width Element.fill
        , Element.spacing (responsiveVal dProfile 30 10)
        , Element.padding (responsiveVal dProfile 20 5)
        ]
        (pagePoints
            |> List.indexedMap
                (\pointNum point ->
                    viewTosPoint dProfile ( boundedPageNum, pointNum ) point
                )
        )


viewTosPoint :
    DisplayProfile
    -> ( Int, Int )
    -> TosCheckbox
    -> Element Msg
viewTosPoint dProfile pointRef point =
    Element.row
        [ Element.width Element.fill
        , Element.spacing (responsiveVal dProfile 15 5)
        ]
        [ Element.el
            [ Element.Font.size
                (responsiveVal dProfile 40 25)
            , Element.alignTop
            ]
          <|
            Element.text EH.bulletPointString
        , Element.column
            [ Element.width Element.fill
            , Element.spacing (responsiveVal dProfile 10 3)
            ]
            [ Element.paragraph []
                point.textEls
            , case point.maybeCheckedString of
                Just checkedString ->
                    viewTosCheckbox dProfile checkedString pointRef

                Nothing ->
                    Element.none
            ]
        ]


viewTosCheckbox :
    DisplayProfile
    -> ( String, Bool )
    -> ( Int, Int )
    -> Element Msg
viewTosCheckbox dProfile ( checkboxText, checked ) pointRef =
    Element.row
        [ Element.Border.rounded 5
        , Element.Background.color <|
            if checked then
                EH.green

            else
                Element.rgb 1 0.3 0.3
        , Element.padding (responsiveVal dProfile 10 5)
        , Element.spacing (responsiveVal dProfile 15 5)
        , Element.Font.size (responsiveVal dProfile 26 12)
        , Element.Font.color EH.white
        , Element.pointer
        , Element.Events.onClick <|
            TosCheckboxClicked pointRef
        ]
        [ Element.el
            [ Element.width <| Element.px (responsiveVal dProfile 30 20)
            , Element.height <| Element.px (responsiveVal dProfile 30 20)
            , Element.Border.rounded 3
            , Element.Border.width 2
            , Element.Border.color <|
                Element.rgba 0 0 0 0.8
            , Element.Background.color <|
                Element.rgba 1 1 1 0.8
            , Element.padding 3
            ]
          <|
            if checked then
                Images.toElement
                    [ Element.height Element.fill
                    , Element.width Element.fill
                    ]
                    Images.checkmark

            else
                Element.none
        , Element.text checkboxText
        ]


viewTosPageNavigationButtons :
    DisplayProfile
    -> ConfirmTosModel
    -> EnterInfo
    -> Element Msg
viewTosPageNavigationButtons dProfile confirmTosModel enterInfo =
    let
        navigationButton text msg =
            Element.el
                [ Element.centerX
                , Element.Border.rounded 5
                , Element.Background.color EH.blue
                , Element.Font.color EH.white
                , Element.Font.size (responsiveVal dProfile 30 12)
                , responsiveVal dProfile (Element.paddingXY 20 10) (Element.padding 8)
                , Element.pointer
                , Element.Events.onClick msg
                , EH.noSelectText
                ]
                (Element.text text)
    in
    Element.row
        [ Element.width Element.fill
        , Element.padding 10
        ]
        [ Element.el
            [ Element.width <| Element.fillPortion 1 ]
          <|
            if confirmTosModel.page /= 0 then
                navigationButton
                    "Previous"
                    TosPreviousPageClicked

            else
                navigationButton
                    "Back"
                    CancelClicked
        , Element.el
            [ Element.width <| Element.fillPortion 1 ]
          <|
            if confirmTosModel.page < (List.length confirmTosModel.points - 1) then
                navigationButton
                    "Next"
                    TosNextPageClicked

            else if isAllPointsChecked confirmTosModel then
                EH.redButton
                    dProfile
                    [ Element.width Element.fill ]
                    [ "Confirm & deposit "
                        ++ TokenValue.toConciseString enterInfo.amount
                        ++ " "
                        ++ Config.enteringTokenCurrencyLabel
                        ++ ""
                    ]
                    (ConfirmClicked enterInfo)

            else
                Element.none
        ]


referralBonusIndicator :
    DisplayProfile
    -> Maybe Address
    -> Bool
    -> Element Msg
referralBonusIndicator dProfile maybeReferrer focusedStyle =
    let
        hasReferral =
            maybeReferrer /= Nothing
    in
    Element.el
        [ Element.paddingXY 16 7
        , Element.Font.bold
        , Element.Font.size (responsiveVal dProfile 18 12)
        , Element.pointer
        , Element.Events.onClick (ReferralIndicatorClicked maybeReferrer)
        , Element.Background.color
            (if hasReferral then
                EH.green

             else
                EH.red
                    |> EH.addAlpha
                        (if focusedStyle then
                            1

                         else
                            0.05
                        )
            )
        , Element.Font.color
            (if focusedStyle then
                EH.white

             else if hasReferral then
                EH.white

             else
                EH.red
            )
        ]
        (Element.text <|
            if hasReferral then
                "Referral Bonus Active"

            else
                "Activate Referral Bonus"
        )


referralModal :
    DisplayProfile
    -> UserInfo
    -> Maybe Address
    -> TestMode
    -> Element Msg
referralModal dProfile userInfo maybeReferrer testMode =
    let
        highlightedText text =
            Element.el
                [ Element.behindContent <|
                    Element.el
                        [ Element.centerX
                        , Element.centerY
                        , Element.padding 1
                        , Element.Background.color green
                        , Element.Font.color EH.white
                        , Element.Border.rounded 2
                        ]
                        (Element.text text)
                , Element.Font.color EH.white
                ]
                (Element.text text)

        mobileFontAttribute =
            case dProfile of
                Desktop ->
                    []

                SmallDesktop ->
                    [ Element.Font.size 12 ]

        ( firstElsChunk, maybeSecondElsChunk ) =
            case maybeReferrer of
                Nothing ->
                    ( [ Element.paragraph
                            [ Element.Font.size <|
                                responsiveVal
                                    dProfile
                                    24
                                    14
                            , Element.Font.bold
                            , Element.Font.color EH.red
                            ]
                            [ Element.text "Oh no! You’ve haven’t got a referral bonus." ]
                      , Element.column
                            [ Element.spacing 20
                            , Element.width Element.fill
                            , Element.Font.size <|
                                responsiveVal
                                    dProfile
                                    18
                                    9
                            ]
                            [ Element.paragraph
                                mobileFontAttribute
                                [ Element.text "You're missing out. Help us market the sale and your friends get an extra "
                                , highlightedText "10% bonus"
                                , Element.text " on their purchase. In addition, you can earn "
                                , highlightedText "10%-20%"
                                , Element.text <| " extra " ++ Config.exitingTokenCurrencyLabel ++ " tokens, based on how much " ++ Config.enteringTokenCurrencyLabel ++ " you refer with this code."
                                ]
                            , Element.paragraph
                                mobileFontAttribute
                                [ Element.text "You can also use your own reference code and get both benefits." ]
                            , Element.paragraph
                                mobileFontAttribute
                                [ Element.newTabLink
                                    [ Element.Font.color <|
                                        EH.lightBlue
                                    ]
                                    { url = "https://youtu.be/AAGZZKpTcuQ"
                                    , label = Element.text "More info on how this works"
                                    }
                                ]
                            , Element.paragraph
                                mobileFontAttribute
                                [ Element.text "If you haven’t been given a referral link you can generate one for yourself below!" ]
                            ]
                      ]
                    , Just <|
                        [ Element.paragraph
                            [ Element.Font.size <|
                                responsiveVal
                                    dProfile
                                    24
                                    14
                            , Element.Font.bold
                            , Element.Font.color deepBlue
                            ]
                            [ Element.text "Your Referral Link" ]
                        , EH.button
                            Desktop
                            [ Element.width Element.fill ]
                            ( deepBlue, deepBlueWithAlpha 0.8, deepBlueWithAlpha 0.6 )
                            EH.white
                            [ "Generate My Referral Link" ]
                            (GenerateReferralClicked userInfo.address)
                        ]
                    )

                Just referrer ->
                    if referrer == userInfo.address then
                        ( [ Element.paragraph
                                [ Element.Font.size <|
                                    responsiveVal
                                        dProfile
                                        24
                                        14
                                , Element.Font.bold
                                , Element.Font.color green
                                ]
                                [ Element.text "Nice! You're using your own referral link." ]
                          , Element.paragraph
                                ([]
                                    ++ mobileFontAttribute
                                )
                                [ Element.text "This means you'll get both bonuses! More info "
                                , Element.newTabLink
                                    ([ Element.Font.color EH.lightBlue ]
                                        ++ mobileFontAttribute
                                    )
                                    { url = "https://youtu.be/AAGZZKpTcuQ"
                                    , label = Element.text "here"
                                    }
                                , Element.text "."
                                ]
                          ]
                        , Just <|
                            [ Element.paragraph
                                [ Element.Font.size <|
                                    responsiveVal
                                        dProfile
                                        24
                                        14
                                , Element.Font.bold
                                , Element.Font.color deepBlue
                                ]
                                [ Element.text "Your Referral Link" ]
                            , referralLinkElement
                                dProfile
                                referrer
                                testMode
                            , referralLinkCopyButton
                                dProfile
                            ]
                        )

                    else
                        ( [ Element.paragraph
                                [ Element.Font.size <|
                                    responsiveVal
                                        dProfile
                                        24
                                        14
                                , Element.Font.bold
                                , Element.Font.color green
                                ]
                                [ Element.text "Nice! You’ve got a referral bonus." ]
                          , Element.paragraph
                                mobileFontAttribute
                                [ Element.text "Every bid you make will result in a bonus bid into the next bucket, at 10% of the first bid amount. Check the next bucket after you enter your bid!" ]
                          , Element.paragraph
                                mobileFontAttribute
                                [ Element.text <| "Share your own referral code with others to earn " ++ Config.exitingTokenCurrencyLabel ++ "! More info "
                                , Element.newTabLink
                                    ([ Element.Font.color EH.lightBlue ]
                                        ++ mobileFontAttribute
                                    )
                                    { url = "https://youtu.be/AAGZZKpTcuQ"
                                    , label = Element.text "here"
                                    }
                                , Element.text "."
                                ]
                          , referralLinkElement
                                dProfile
                                userInfo.address
                                testMode
                          , referralLinkCopyButton
                                dProfile
                          ]
                        , Nothing
                        )
    in
    Element.column
        [ Element.Border.rounded 6
        , Element.Background.color EH.white
        , Element.width <|
            responsiveVal
                dProfile
                (Element.px 480)
                Element.fill
        ]
        [ Element.column
            [ Element.width Element.fill
            , Element.Border.widthEach
                { bottom =
                    if maybeSecondElsChunk == Nothing then
                        0

                    else
                        1
                , top = 0
                , right = 0
                , left = 0
                }
            , Element.Border.dashed
            , Element.Border.color <| Element.rgb 0.5 0.5 0.5
            , Element.padding <|
                responsiveVal
                    dProfile
                    30
                    15
            , Element.spacing <|
                responsiveVal
                    dProfile
                    30
                    15
            ]
            firstElsChunk
        , Maybe.map
            (Element.column
                [ Element.width Element.fill
                , Element.padding <|
                    responsiveVal
                        dProfile
                        30
                        15
                , Element.spacing <|
                    responsiveVal
                        dProfile
                        30
                        15
                ]
            )
            maybeSecondElsChunk
            |> Maybe.withDefault Element.none
        ]


referralLinkElement :
    DisplayProfile
    -> Address
    -> TestMode
    -> Element Msg
referralLinkElement dProfile referrerAddress testMode =
    Element.el
        [ Element.width Element.fill
        , Element.Background.color <| deepBlueWithAlpha 0.05
        , Element.paddingXY 5 15
        , Element.Font.color deepBlue
        , Element.Font.size <|
            responsiveVal
                dProfile
                12
                10
        , Element.clipX
        , Element.scrollbarX
        ]
        (case dProfile of
            Desktop ->
                Element.el
                    [ EH.withIdAttribute "copyable-link" ]
                <|
                    Element.text
                        (Routing.FullRoute
                            testMode
                            Routing.Sale
                            (Just referrerAddress)
                            |> Routing.routeToString
                            |> (\path -> "https://sale.foundrydao.com" ++ path)
                        )

            SmallDesktop ->
                Element.paragraph
                    [ EH.withIdAttribute "copyable-link" ]
                <|
                    [ Element.text
                        (Routing.FullRoute
                            testMode
                            Routing.Sale
                            (Just referrerAddress)
                            |> Routing.routeToString
                            |> (\path -> "https://sale.foundrydao.com" ++ path)
                        )
                    ]
        )


referralLinkCopyButton :
    DisplayProfile
    -> Element Msg
referralLinkCopyButton dProfile =
    EH.button
        dProfile
        [ Element.width Element.fill
        , Element.htmlAttribute <|
            Html.Attributes.attribute
                "data-clipboard-target"
                "#copyable-link"
        , Element.htmlAttribute <|
            Html.Attributes.class "link-copy-btn"
        ]
        ( deepBlue, deepBlueWithAlpha 0.8, deepBlueWithAlpha 0.6 )
        EH.white
        [ "Copy Link" ]
        NoOp


progressBarElement :
    Element.Color
    -> List ( Float, Element.Color )
    -> Element Msg
progressBarElement bgColor ratiosAndColors =
    Element.row
        [ Element.width Element.fill
        , Element.Background.color bgColor
        , Element.Border.rounded 4
        , Element.height <| Element.px 8
        , Element.clip
        ]
    <|
        let
            leftoverRatio =
                1
                    - (ratiosAndColors
                        |> List.map Tuple.first
                        |> List.sum
                      )

            progressBarEls =
                ratiosAndColors
                    |> List.map
                        (\( ratio, color ) ->
                            Element.el
                                [ Element.width <| Element.fillPortion (ratio * 2000 |> floor)
                                , Element.Background.color color
                                , Element.height Element.fill
                                ]
                                Element.none
                        )
        in
        progressBarEls
            ++ [ Element.el
                    [ Element.width <| Element.fillPortion (leftoverRatio * 2000 |> floor) ]
                    Element.none
               ]


emphasizedText :
    CommonBlockStyle
    -> (String -> Element Msg)
emphasizedText styleType =
    Element.el
        (case styleType of
            ActiveStyle ->
                [ Element.Font.color EH.white ]

            PassiveStyle ->
                [ Element.Font.color deepBlue ]
        )
        << Element.text


type CommonBlockStyle
    = ActiveStyle
    | PassiveStyle


centerpaneBlockContainer :
    DisplayProfile
    -> CommonBlockStyle
    -> List (Attribute Msg)
    -> List (Element Msg)
    -> Element Msg
centerpaneBlockContainer dProfile styleType attributes =
    Element.column
        ([ Element.width Element.fill
         , Element.Border.rounded 4
         , Element.padding <|
            responsiveVal dProfile 20 10
         , Element.spacing <|
            responsiveVal dProfile 13 7
         , Element.Font.size <|
            responsiveVal dProfile 16 10
         ]
            ++ attributes
            ++ (case styleType of
                    ActiveStyle ->
                        [ Element.Background.color deepBlue
                        , Element.Font.color <| Element.rgba 1 1 1 0.6
                        ]

                    PassiveStyle ->
                        [ Element.Background.color gray ]
               )
        )


sidepaneBlockContainer :
    DisplayProfile
    -> CommonBlockStyle
    -> List (Element Msg)
    -> Element Msg
sidepaneBlockContainer dProfile styleType =
    Element.column
        ([ Element.width Element.fill
         , Element.Border.rounded 4
         , Element.paddingXY
            (responsiveVal dProfile 22 11)
            (responsiveVal dProfile 18 9)
         , Element.spacing
            (responsiveVal dProfile 16 8)
         ]
            ++ (case styleType of
                    ActiveStyle ->
                        [ Element.Background.color deepBlue
                        , Element.Font.color <| Element.rgba 1 1 1 0.6
                        ]

                    PassiveStyle ->
                        [ Element.Background.color <| deepBlueWithAlpha 0.05
                        , Element.Font.color <| deepBlueWithAlpha 0.3
                        ]
               )
        )


type NumberVal
    = IntegerNum Int
    | TokenNum TokenValue


numberValToString :
    NumberVal
    -> String
numberValToString numberVal =
    case numberVal of
        IntegerNum intVal ->
            formatFloat 0 (toFloat intVal)

        TokenNum tokenValue ->
            TokenValue.toConciseString tokenValue


bigNumberElement :
    DisplayProfile
    -> List (Attribute Msg)
    -> NumberVal
    -> String
    -> CommonBlockStyle
    -> Element Msg
bigNumberElement dProfile attributes numberVal numberLabel blockStyle =
    Element.el
        (attributes
            ++ [ Element.Font.size (responsiveVal dProfile 27 12)
               , Element.Font.bold
               , Element.Font.color
                    (case blockStyle of
                        ActiveStyle ->
                            EH.white

                        PassiveStyle ->
                            deepBlue
                    )
               ]
        )
        (Element.text
            (numberValToString numberVal
                ++ " "
                ++ numberLabel
            )
        )


makeClaimButton :
    DisplayProfile
    -> UserInfo
    -> ExitInfo
    -> Element Msg
makeClaimButton dProfile userInfo exitInfo =
    EH.lightBlueButton
        dProfile
        [ Element.width Element.fill ]
        [ "Claim your " ++ Config.exitingTokenCurrencyLabel ++ "" ]
        (ClaimClicked userInfo exitInfo)


jumpToCurrentBucketButton :
    DisplayProfile
    -> Int
    -> Element Msg
jumpToCurrentBucketButton dProfile currentBucketId =
    case dProfile of
        Desktop ->
            Element.el
                [ Element.pointer
                , Element.Events.onClick (FocusToBucket currentBucketId)
                , Element.Font.color EH.lightBlue
                , Element.Font.size (responsiveVal dProfile 20 10)
                ]
                (Element.text "Return to Current Bucket")

        SmallDesktop ->
            EH.lightBlueButton
                dProfile
                [ Element.alignRight ]
                [ "Return to Current Bucket" ]
                (FocusToBucket currentBucketId)


loadingElement : Element Msg
loadingElement =
    Element.text "Loading"


gray : Element.Color
gray =
    Element.rgb255 235 237 243


deepBlue : Element.Color
deepBlue =
    Element.rgb255 10 33 109


lightBlue : Element.Color
lightBlue =
    Element.rgb255 25 169 214


purple : Element.Color
purple =
    Element.rgb255 212 0 255


deepBlueWithAlpha :
    Float
    -> Element.Color
deepBlueWithAlpha a =
    deepBlue
        |> EH.addAlpha a


grayTextColor : Element.Color
grayTextColor =
    Element.rgba255 1 31 52 0.75


orangeWarningColor : Element.Color
orangeWarningColor =
    Element.rgb255 252 106 3


green : Element.Color
green =
    Element.rgb255 0 162 149


connectToWeb3Button :
    DisplayProfile
    -> Wallet.State
    -> Element Msg
connectToWeb3Button dProfile wallet =
    let
        commonButtonStyles =
            [ Element.width Element.fill
            , Element.padding 17
            , Element.Border.rounded 4
            , Element.Font.size <| responsiveVal dProfile 20 16
            , Element.Font.semiBold
            , Element.Font.center
            , Element.Background.color EH.softRed
            , Element.Font.color EH.white
            , Element.pointer
            ]

        commonTextStyles =
            [ Element.Font.bold
            , Element.Font.italic
            , Element.Font.size <| responsiveVal dProfile 20 16
            , Element.Font.center
            , Element.padding 17
            , Element.centerX
            ]
    in
    case wallet of
        Wallet.NoneDetected ->
            Element.el
                (commonTextStyles
                    ++ [ Element.Font.color EH.softRed ]
                )
                (Element.text "No web3 wallet found")

        Wallet.OnlyNetwork _ ->
            Element.el
                (commonButtonStyles
                    ++ [ Element.Events.onClick <| CmdUp CmdUp.Web3Connect ]
                )
                (Element.text "Connect to Wallet")

        Wallet.WrongNetwork ->
            Element.el
                (commonTextStyles
                    ++ [ Element.Font.color EH.softRed ]
                )
                (Element.text "Your web3 wallet is on the wrong network.")

        Wallet.Active _ ->
            Element.el
                (commonTextStyles
                    ++ [ Element.Font.color EH.green ]
                )
                (Element.text "Wallet connected!")


verifyJurisdictionErrorEl :
    DisplayProfile
    -> JurisdictionCheckStatus
    -> List (Attribute Msg)
    -> Element Msg
verifyJurisdictionErrorEl dProfile jurisdictionCheckStatus attributes =
    case jurisdictionCheckStatus of
        Error errStr ->
            Element.column
                ([ Element.spacing <|
                    responsiveVal
                        dProfile
                        20
                        10

                 --, Element.width Element.fill
                 , Element.Font.size <|
                    responsiveVal
                        dProfile
                        16
                        8
                 ]
                    ++ attributes
                )
                [ Element.el
                    []
                  <|
                    Element.text errStr
                , Element.text "There may be more info in the console."
                ]

        _ ->
            Element.none
