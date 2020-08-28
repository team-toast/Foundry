port module BucketSale.State exposing (init, runCmdDown, subscriptions, update)

import BigInt exposing (BigInt)
import BucketSale.Types exposing (..)
import ChainCmd exposing (ChainCmd)
import CmdDown exposing (CmdDown)
import CmdUp exposing (CmdUp)
import CommonTypes exposing (..)
import Config exposing (forbiddenJurisdictionCodes)
import Contracts.BucketSale.Wrappers as BucketSaleWrappers
import Contracts.Wrappers
import Dict exposing (Dict)
import Element exposing (Element)
import Element.Font
import Eth
import Eth.Net
import Eth.Types exposing (Address, HttpProvider, Tx, TxHash, TxReceipt)
import Eth.Utils
import Helpers.BigInt as BigIntHelpers
import Helpers.Element as EH
import Helpers.Eth as EthHelpers
import Helpers.Http as HttpHelpers
import Helpers.Time as TimeHelpers
import Http
import Json.Decode
import Json.Decode.Extra
import Json.Encode
import List.Extra
import Maybe.Extra
import Result.Extra
import Set
import Task
import Time
import TokenValue exposing (TokenValue)
import Utils
import Wallet


init : Maybe Address -> TestMode -> Wallet.State -> Time.Posix -> ( Model, Cmd Msg )
init maybeReferrer testMode wallet now =
    ( { wallet = verifyWalletCorrectNetwork wallet testMode
      , extraUserInfo = Nothing
      , testMode = testMode
      , now = now
      , timezone = Nothing
      , fastGasPrice = Nothing
      , saleStartTime = Nothing
      , bucketSale = Nothing
      , totalTokensExited = Nothing
      , bucketView = ViewCurrent
      , jurisdictionCheckStatus = WaitingForClick
      , enterUXModel = initEnterUXModel maybeReferrer
      , trackedTxs = []
      , confirmTosModel = initConfirmTosModel
      , enterInfoToConfirm = Nothing
      , showReferralModal = False
      , showFeedbackUXModel = False
      , feedbackUXModel =
            initFeedbackUXModel
      }
    , Cmd.batch
        [ fetchSaleStartTimestampCmd testMode
        , fetchFastGasPriceCmd
        , Task.perform TimezoneGot Time.here
        , fetchStateUpdateInfoCmd
            (Wallet.userInfo wallet)
            Nothing
            testMode
        ]
    )


initConfirmTosModel : ConfirmTosModel
initConfirmTosModel =
    { points =
        tosLines
            |> (List.map >> List.map)
                (\( text, maybeAgreeText ) ->
                    TosCheckbox
                        text
                        (maybeAgreeText
                            |> Maybe.map
                                (\agreeText -> ( agreeText, False ))
                        )
                )
    , page = 0
    }


verifyWalletCorrectNetwork : Wallet.State -> TestMode -> Wallet.State
verifyWalletCorrectNetwork wallet testMode =
    case ( testMode, Wallet.network wallet ) of
        ( None, Just Eth.Net.Mainnet ) ->
            wallet

        ( TestMainnet, Just Eth.Net.Mainnet ) ->
            wallet

        ( TestKovan, Just Eth.Net.Kovan ) ->
            wallet

        ( TestGanache, Just (Eth.Net.Private 123456) ) ->
            wallet

        _ ->
            Wallet.WrongNetwork


initEnterUXModel : Maybe Address -> EnterUXModel
initEnterUXModel maybeReferrer =
    { daiInput = ""
    , daiAmount = Nothing
    , referrer = maybeReferrer
    }


update : Msg -> Model -> UpdateResult
update msg prevModel =
    case msg of
        NoOp ->
            justModelUpdate prevModel

        CmdUp cmdUp ->
            UpdateResult
                prevModel
                Cmd.none
                ChainCmd.none
                [ cmdUp ]

        TimezoneGot tz ->
            justModelUpdate
                { prevModel | timezone = Just tz }

        Refresh ->
            let
                fetchStateCmd =
                    fetchStateUpdateInfoCmd
                        (Wallet.userInfo prevModel.wallet)
                        (case prevModel.bucketSale of
                            Just (Ok bucketSale) ->
                                Just <| getFocusedBucketId bucketSale prevModel.bucketView prevModel.now prevModel.testMode

                            _ ->
                                Nothing
                        )
                        prevModel.testMode

                checkTxsCmd =
                    prevModel.trackedTxs
                        |> List.indexedMap
                            (\id trackedTx ->
                                case trackedTx.status of
                                    Signed txHash Mining ->
                                        Just
                                            (Eth.getTxReceipt
                                                (EthHelpers.appHttpProvider prevModel.testMode)
                                                txHash
                                                |> Task.attempt
                                                    (TxStatusFetched id trackedTx.action)
                                            )

                                    _ ->
                                        Nothing
                            )
                        |> Maybe.Extra.values
                        |> Cmd.batch
            in
            UpdateResult
                prevModel
                (Cmd.batch
                    [ fetchStateCmd
                    , checkTxsCmd
                    ]
                )
                ChainCmd.none
                []

        UpdateNow newNow ->
            let
                cmd =
                    case ( prevModel.bucketSale, prevModel.bucketView ) of
                        ( Nothing, _ ) ->
                            Cmd.none

                        ( Just (Err _), _ ) ->
                            Cmd.none

                        ( _, ViewId _ ) ->
                            Cmd.none

                        ( Just (Ok bucketSale), ViewCurrent ) ->
                            let
                                newFocusedId =
                                    getCurrentBucketId bucketSale newNow prevModel.testMode
                            in
                            if newFocusedId /= getCurrentBucketId bucketSale prevModel.now prevModel.testMode then
                                fetchBucketDataCmd
                                    newFocusedId
                                    (Wallet.userInfo prevModel.wallet)
                                    prevModel.testMode

                            else
                                Cmd.none
            in
            UpdateResult
                { prevModel
                    | now = newNow
                }
                cmd
                ChainCmd.none
                []

        FetchFastGasPrice ->
            UpdateResult
                prevModel
                fetchFastGasPriceCmd
                ChainCmd.none
                []

        FetchedFastGasPrice fetchResult ->
            case fetchResult of
                Err httpErr ->
                    -- Just ignore it
                    let
                        _ =
                            Debug.log "error fetching gasstation info" httpErr
                    in
                    justModelUpdate prevModel

                Ok fastGasPrice ->
                    justModelUpdate
                        { prevModel
                            | fastGasPrice = Just fastGasPrice
                        }

        TosPreviousPageClicked ->
            justModelUpdate
                { prevModel
                    | confirmTosModel =
                        let
                            prevTosModel =
                                prevModel.confirmTosModel
                        in
                        { prevTosModel
                            | page =
                                max
                                    (prevTosModel.page - 1)
                                    0
                        }
                }

        TosNextPageClicked ->
            justModelUpdate
                { prevModel
                    | confirmTosModel =
                        let
                            prevTosModel =
                                prevModel.confirmTosModel
                        in
                        { prevTosModel
                            | page =
                                min
                                    (prevTosModel.page + 1)
                                    (List.length prevTosModel.points)
                        }
                }

        TosCheckboxClicked pointRef ->
            let
                newConfirmTosModel =
                    prevModel.confirmTosModel
                        |> toggleAssentForPoint pointRef
            in
            UpdateResult
                { prevModel
                    | confirmTosModel =
                        newConfirmTosModel
                }
                Cmd.none
                ChainCmd.none
                (if isAllPointsChecked newConfirmTosModel then
                    [ CmdUp.gTag
                        "7 - agree to all"
                        "funnel"
                        ""
                        0
                    ]

                 else
                    []
                )

        AddFryToMetaMaskClicked ->
            UpdateResult
                prevModel
                (addFryToMetaMask ())
                ChainCmd.none
                [ CmdUp.gTag
                    "10 - User requested FRY to be added to MetaMask"
                    "funnel"
                    ""
                    0
                ]

        VerifyJurisdictionClicked ->
            UpdateResult
                { prevModel
                    | jurisdictionCheckStatus = Checking
                }
                (beginLocationCheck ())
                ChainCmd.none
                [ CmdUp.gTag
                    "3a - verify jurisdiction clicked"
                    "funnel"
                    ""
                    0
                ]

        FeedbackButtonClicked ->
            justModelUpdate
                { prevModel
                    | showFeedbackUXModel = True
                }

        FeedbackEmailChanged newEmail ->
            justModelUpdate
                { prevModel
                    | feedbackUXModel =
                        let
                            prev =
                                prevModel.feedbackUXModel
                        in
                        { prev | email = newEmail }
                            |> updateAnyFeedbackUXErrors
                }

        FeedbackDescriptionChanged newDescription ->
            justModelUpdate
                { prevModel
                    | feedbackUXModel =
                        let
                            prev =
                                prevModel.feedbackUXModel
                        in
                        { prev | description = newDescription }
                            |> updateAnyFeedbackUXErrors
                }

        FeedbackSubmitClicked ->
            let
                prevFeedbackModel =
                    prevModel.feedbackUXModel
            in
            case validateFeedbackInput prevModel.feedbackUXModel of
                Ok validated ->
                    UpdateResult
                        { prevModel
                            | feedbackUXModel =
                                { prevFeedbackModel | sendState = Sending }
                        }
                        (sendFeedbackCmd validated Nothing)
                        ChainCmd.none
                        [ CmdUp.gTag
                            "feedback submitted"
                            "feedback"
                            (let
                                combinedStr =
                                    (validated.email |> Maybe.withDefault "[none]")
                                        ++ ":"
                                        ++ validated.description
                             in
                             combinedStr |> String.left 30
                            )
                            0
                        ]

                Err errStr ->
                    justModelUpdate
                        { prevModel
                            | feedbackUXModel =
                                { prevFeedbackModel | maybeError = Just errStr }
                        }

        FeedbackHttpResponse responseResult ->
            let
                newFeedbackUX =
                    let
                        prevFeedbackUX =
                            prevModel.feedbackUXModel
                    in
                    case responseResult of
                        Err httpErr ->
                            { prevFeedbackUX
                                | sendState = SendFailed <| HttpHelpers.errorToString httpErr
                            }

                        Ok _ ->
                            { prevFeedbackUX
                                | sendState = Sent
                                , description = ""
                                , debugString = Nothing
                                , maybeError = Nothing
                            }
            in
            UpdateResult
                { prevModel | feedbackUXModel = newFeedbackUX }
                Cmd.none
                ChainCmd.none
                []

        FeedbackBackClicked ->
            justModelUpdate
                { prevModel
                    | showFeedbackUXModel = False
                }

        FeedbackSendMoreClicked ->
            justModelUpdate
                { prevModel
                    | feedbackUXModel =
                        let
                            prev =
                                prevModel.feedbackUXModel
                        in
                        { prev
                            | sendState = NotSent
                        }
                }

        LocationCheckResult decodeResult ->
            let
                jurisdictionCheckStatus =
                    locationCheckResultToJurisdictionStatus decodeResult
            in
            UpdateResult
                { prevModel
                    | jurisdictionCheckStatus = jurisdictionCheckStatus
                }
                Cmd.none
                ChainCmd.none
                (case jurisdictionCheckStatus of
                    WaitingForClick ->
                        []

                    Checking ->
                        []

                    Checked ForbiddenJurisdictions ->
                        [ CmdUp.gTag
                            "jurisdiction not allowed"
                            "funnel abort"
                            ""
                            0
                        ]

                    Checked _ ->
                        [ CmdUp.gTag
                            "3b - jurisdiction verified"
                            "funnel"
                            ""
                            0
                        ]

                    Error error ->
                        [ CmdUp.gTag
                            "failed jursidiction check"
                            "funnel abort"
                            error
                            0
                        ]
                )

        SaleStartTimestampFetched fetchResult ->
            case fetchResult of
                Ok startTimestampBigInt ->
                    if BigInt.compare startTimestampBigInt (BigInt.fromInt 0) == EQ then
                        justModelUpdate
                            { prevModel
                                | bucketSale = Just <| Err "The sale has not been initialized yet."
                            }

                    else
                        let
                            startTimestamp =
                                TimeHelpers.secondsBigIntToPosixWithWarning startTimestampBigInt

                            ( newMaybeResultBucketSale, cmd ) =
                                case prevModel.bucketSale of
                                    Nothing ->
                                        case initBucketSale prevModel.testMode startTimestamp prevModel.now of
                                            Ok sale ->
                                                ( Just <| Ok sale
                                                , fetchBucketDataCmd
                                                    (getCurrentBucketId
                                                        sale
                                                        prevModel.now
                                                        prevModel.testMode
                                                    )
                                                    (Wallet.userInfo prevModel.wallet)
                                                    prevModel.testMode
                                                )

                                            Err errStr ->
                                                ( Just <| Err errStr
                                                , Cmd.none
                                                )

                                    _ ->
                                        ( prevModel.bucketSale
                                        , Cmd.none
                                        )
                        in
                        UpdateResult
                            { prevModel
                                | bucketSale = newMaybeResultBucketSale
                                , saleStartTime = Just startTimestamp
                            }
                            cmd
                            ChainCmd.none
                            []

                Err httpErr ->
                    let
                        _ =
                            Debug.log "http error when fetching sale startTime" httpErr
                    in
                    justModelUpdate prevModel

        BucketValueEnteredFetched bucketId fetchResult ->
            case fetchResult of
                Err httpErr ->
                    let
                        _ =
                            Debug.log "http error when fetching total bucket value entered" ( bucketId, fetchResult )
                    in
                    justModelUpdate prevModel

                Ok valueEntered ->
                    case prevModel.bucketSale of
                        Just (Ok oldBucketSale) ->
                            let
                                maybeNewBucketSale =
                                    oldBucketSale
                                        |> updateBucketAt
                                            bucketId
                                            (\bucket ->
                                                { bucket | totalValueEntered = Just valueEntered }
                                            )
                            in
                            case maybeNewBucketSale of
                                Nothing ->
                                    let
                                        _ =
                                            Debug.log "Warning! Somehow trying to update a bucket that doesn't exist!" ""
                                    in
                                    justModelUpdate prevModel

                                Just newBucketSale ->
                                    justModelUpdate
                                        { prevModel
                                            | bucketSale =
                                                Just (Ok newBucketSale)
                                        }

                        somethingElse ->
                            let
                                _ =
                                    Debug.log "Warning! Bucket value fetched but there is no bucketSale present!" somethingElse
                            in
                            justModelUpdate prevModel

        UserBuyFetched userAddress bucketId fetchResult ->
            if (Wallet.userInfo prevModel.wallet |> Maybe.map .address) /= Just userAddress then
                justModelUpdate prevModel

            else
                case fetchResult of
                    Err httpErr ->
                        let
                            _ =
                                Debug.log "http error when fetching buy for user" ( userAddress, bucketId, httpErr )
                        in
                        justModelUpdate prevModel

                    Ok bindingBuy ->
                        let
                            buy =
                                buyFromBindingBuy bindingBuy
                        in
                        case prevModel.bucketSale of
                            Just (Ok oldBucketSale) ->
                                let
                                    maybeNewBucketSale =
                                        oldBucketSale
                                            |> updateBucketAt
                                                bucketId
                                                (\bucket ->
                                                    { bucket
                                                        | userBuy = Just buy
                                                    }
                                                )
                                in
                                case maybeNewBucketSale of
                                    Nothing ->
                                        let
                                            _ =
                                                Debug.log "Warning! Somehow trying to update a bucket that does not exist or is in the future!" ""
                                        in
                                        justModelUpdate prevModel

                                    Just newBucketSale ->
                                        justModelUpdate
                                            { prevModel | bucketSale = Just <| Ok newBucketSale }

                            somethingElse ->
                                let
                                    _ =
                                        Debug.log "Warning! Bucket value fetched but there is no bucketSale present!" somethingElse
                                in
                                justModelUpdate prevModel

        StateUpdateInfoFetched fetchResult ->
            case fetchResult of
                Err httpErr ->
                    let
                        _ =
                            Debug.log "http error when fetching stateUpdateInfo" httpErr
                    in
                    justModelUpdate prevModel

                Ok Nothing ->
                    let
                        _ =
                            Debug.log "Query contract returned an invalid result" ""
                    in
                    justModelUpdate prevModel

                Ok (Just stateUpdateInfo) ->
                    let
                        newModel =
                            prevModel
                                |> (\model ->
                                        case Wallet.userInfo prevModel.wallet of
                                            Nothing ->
                                                prevModel

                                            Just userInfo ->
                                                case stateUpdateInfo.maybeUserStateInfo of
                                                    Nothing ->
                                                        prevModel

                                                    Just fetchedUserStateInfo ->
                                                        if Tuple.first fetchedUserStateInfo /= userInfo.address then
                                                            prevModel

                                                        else
                                                            { prevModel
                                                                | extraUserInfo =
                                                                    Just <| Tuple.second <| fetchedUserStateInfo
                                                            }
                                   )
                                |> (\model ->
                                        case prevModel.bucketSale of
                                            Just (Ok oldBucketSale) ->
                                                let
                                                    maybeNewBucketSale =
                                                        oldBucketSale
                                                            |> updateBucketAt
                                                                stateUpdateInfo.bucketInfo.bucketId
                                                                (\bucket ->
                                                                    { bucket
                                                                        | userBuy =
                                                                            Just <|
                                                                                { valueEntered = stateUpdateInfo.bucketInfo.userDaiEntered
                                                                                , hasExited = not <| TokenValue.isZero stateUpdateInfo.bucketInfo.userFryExited
                                                                                }
                                                                        , totalValueEntered = Just stateUpdateInfo.bucketInfo.totalDaiEntered
                                                                    }
                                                                )
                                                in
                                                case maybeNewBucketSale of
                                                    Nothing ->
                                                        let
                                                            _ =
                                                                Debug.log "Warning! Somehow trying to update a bucket that does not exist or is in the future!" ""
                                                        in
                                                        model

                                                    Just newBucketSale ->
                                                        { model | bucketSale = Just <| Ok newBucketSale }

                                            _ ->
                                                model
                                   )
                                |> (\model ->
                                        { model
                                            | totalTokensExited = Just stateUpdateInfo.totalTokensExited
                                        }
                                   )

                        ( ethBalance, daiBalance ) =
                            case stateUpdateInfo.maybeUserStateInfo of
                                Nothing ->
                                    ( TokenValue.zero
                                    , TokenValue.zero
                                    )

                                Just userStateInfo ->
                                    ( Tuple.second userStateInfo |> .ethBalance
                                    , Tuple.second userStateInfo |> .daiBalance
                                    )
                    in
                    UpdateResult
                        newModel
                        Cmd.none
                        ChainCmd.none
                        ((if not <| TokenValue.isZero ethBalance then
                            [ CmdUp.nonRepeatingGTag
                                "2a - has ETH"
                                "funnel"
                                (TokenValue.toConciseString ethBalance)
                                0
                            ]

                          else
                            []
                         )
                            ++ (if not <| TokenValue.isZero daiBalance then
                                    [ CmdUp.nonRepeatingGTag
                                        "2b - has DAI"
                                        "funnel"
                                        (TokenValue.toConciseString daiBalance)
                                        0
                                    ]

                                else
                                    []
                               )
                        )

        TotalTokensExitedFetched fetchResult ->
            case fetchResult of
                Err httpErr ->
                    let
                        _ =
                            Debug.log "http error when fetching totalTokensExited" httpErr
                    in
                    justModelUpdate prevModel

                Ok totalTokensExited ->
                    justModelUpdate
                        { prevModel
                            | totalTokensExited = Just totalTokensExited
                        }

        FocusToBucket bucketId ->
            case prevModel.bucketSale of
                Just (Ok bucketSale) ->
                    let
                        newBucketView =
                            if bucketId == getCurrentBucketId bucketSale prevModel.now prevModel.testMode then
                                ViewCurrent

                            else
                                ViewId
                                    (bucketId
                                        |> min Config.bucketSaleNumBuckets
                                        |> max
                                            (getCurrentBucketId
                                                bucketSale
                                                prevModel.now
                                                prevModel.testMode
                                            )
                                    )

                        maybeFetchBucketDataCmd =
                            let
                                bucketInfo =
                                    getBucketInfo
                                        bucketSale
                                        (getFocusedBucketId
                                            bucketSale
                                            newBucketView
                                            prevModel.now
                                            prevModel.testMode
                                        )
                                        prevModel.now
                                        prevModel.testMode
                            in
                            case bucketInfo of
                                ValidBucket bucketData ->
                                    fetchBucketDataCmd
                                        bucketId
                                        (Wallet.userInfo prevModel.wallet)
                                        prevModel.testMode

                                _ ->
                                    Cmd.none
                    in
                    UpdateResult
                        { prevModel
                            | bucketView = newBucketView
                        }
                        maybeFetchBucketDataCmd
                        ChainCmd.none
                        [ CmdUp.gTag "focus to bucket"
                            "navigation"
                            (String.fromInt bucketId)
                            1
                        ]

                somethingElse ->
                    let
                        _ =
                            Debug.log "Bucket clicked, but bucketSale isn't loaded! What??" somethingElse
                    in
                    justModelUpdate prevModel

        DaiInputChanged input ->
            UpdateResult
                { prevModel
                    | enterUXModel =
                        let
                            oldEnterUXModel =
                                prevModel.enterUXModel
                        in
                        { oldEnterUXModel
                            | daiInput = input
                            , daiAmount =
                                if input == "" then
                                    Nothing

                                else
                                    Just <| validateDaiInput input
                        }
                }
                Cmd.none
                ChainCmd.none
                [ CmdUp.gTag
                    "5? - dai input changed"
                    "funnel"
                    input
                    0
                ]

        ReferralIndicatorClicked ->
            UpdateResult
                { prevModel
                    | showReferralModal =
                        if prevModel.showReferralModal then
                            False

                        else
                            True
                }
                Cmd.none
                ChainCmd.none
                [ CmdUp.gTag "modal shown" "referral" (maybeReferrerToString prevModel.enterUXModel.referrer) 0 ]

        CloseReferralModal ->
            UpdateResult
                { prevModel
                    | showReferralModal = False
                }
                Cmd.none
                ChainCmd.none
                [ CmdUp.gTag "modal hidden" "referral" (maybeReferrerToString prevModel.enterUXModel.referrer) 0 ]

        GenerateReferralClicked address ->
            UpdateResult
                prevModel
                Cmd.none
                ChainCmd.none
                [ CmdUp.NewReferralGenerated address
                , CmdUp.gTag "generate referral" "referral" (Eth.Utils.addressToString address) 0
                ]

        UnlockDaiButtonClicked ->
            let
                ( trackedTxId, newTrackedTxs ) =
                    prevModel.trackedTxs
                        |> trackNewTx
                            (TrackedTx
                                Unlock
                                Signing
                            )

                chainCmd =
                    let
                        customSend =
                            { onMined = Nothing
                            , onSign = Just <| TxSigned trackedTxId Unlock
                            , onBroadcast = Nothing
                            }

                        txParams =
                            BucketSaleWrappers.unlockDai prevModel.testMode
                                |> Eth.toSend
                    in
                    ChainCmd.custom customSend txParams
            in
            UpdateResult
                { prevModel
                    | trackedTxs = newTrackedTxs
                }
                Cmd.none
                chainCmd
                [ CmdUp.gTag
                    "4a - unlock clicked"
                    "funnel"
                    ""
                    0
                ]

        EnterButtonClicked enterInfo ->
            UpdateResult
                { prevModel
                    | enterInfoToConfirm = Just enterInfo
                }
                Cmd.none
                ChainCmd.none
                [ CmdUp.gTag
                    "6 - enter clicked"
                    "funnel"
                    (TokenValue.toFloatString Nothing enterInfo.amount)
                    0
                ]

        CancelClicked ->
            UpdateResult
                { prevModel
                    | enterInfoToConfirm = Nothing
                }
                Cmd.none
                ChainCmd.none
                [ CmdUp.gTag
                    "tos aborted"
                    "funnel abort"
                    ""
                    0
                ]

        ConfirmClicked enterInfo ->
            let
                actionData =
                    Enter enterInfo

                ( trackedTxId, newTrackedTxs ) =
                    prevModel.trackedTxs
                        |> trackNewTx
                            (TrackedTx
                                actionData
                                Signing
                            )

                chainCmd =
                    let
                        customSend =
                            { onMined = Nothing
                            , onSign = Just <| TxSigned trackedTxId actionData
                            , onBroadcast = Nothing
                            }

                        txParams =
                            BucketSaleWrappers.enter
                                enterInfo.userInfo.address
                                enterInfo.bucketId
                                enterInfo.amount
                                enterInfo.maybeReferrer
                                prevModel.fastGasPrice
                                prevModel.testMode
                                |> Eth.toSend
                    in
                    ChainCmd.custom customSend txParams
            in
            UpdateResult
                { prevModel
                    | trackedTxs = newTrackedTxs
                    , enterInfoToConfirm = Nothing
                }
                Cmd.none
                chainCmd
                [ CmdUp.gTag
                    "8a - confirm clicked"
                    "funnel"
                    (TokenValue.toFloatString Nothing enterInfo.amount)
                    0
                ]

        ClaimClicked userInfo exitInfo ->
            let
                ( trackedTxId, newTrackedTxs ) =
                    prevModel.trackedTxs
                        |> trackNewTx
                            (TrackedTx
                                Exit
                                Signing
                            )

                chainCmd =
                    let
                        customSend =
                            { onMined = Nothing
                            , onSign = Just <| TxSigned trackedTxId Exit
                            , onBroadcast = Nothing
                            }

                        txParams =
                            BucketSaleWrappers.exitMany
                                userInfo.address
                                exitInfo.exitableBuckets
                                prevModel.testMode
                                |> Eth.toSend
                    in
                    ChainCmd.custom customSend txParams
            in
            UpdateResult
                { prevModel
                    | trackedTxs = newTrackedTxs
                }
                Cmd.none
                chainCmd
                [ CmdUp.gTag
                    "claim clicked"
                    "after sale"
                    (exitInfo.totalExitable
                        |> TokenValue.toFloatString Nothing
                    )
                    0
                ]

        TxSigned trackedTxId actionData txHashResult ->
            case txHashResult of
                Err errStr ->
                    let
                        _ =
                            Debug.log "Error signing tx" ( actionData, errStr )
                    in
                    UpdateResult
                        { prevModel
                            | trackedTxs =
                                prevModel.trackedTxs
                                    |> updateTrackedTxStatus trackedTxId Rejected
                        }
                        Cmd.none
                        ChainCmd.none
                        [ CmdUp.gTag
                            (actionDataToString actionData ++ " tx sign error")
                            "funnel abort - tx"
                            errStr
                            0
                        ]

                Ok txHash ->
                    let
                        newTrackedTxs =
                            prevModel.trackedTxs
                                |> updateTrackedTxStatus trackedTxId (Signed txHash Mining)

                        newEnterUXModel =
                            case actionData of
                                Enter enterInfo ->
                                    let
                                        oldEnterUXModel =
                                            prevModel.enterUXModel
                                    in
                                    { oldEnterUXModel
                                        | daiInput = ""
                                        , daiAmount = Nothing
                                    }

                                _ ->
                                    prevModel.enterUXModel
                    in
                    UpdateResult
                        { prevModel
                            | trackedTxs = newTrackedTxs
                            , enterUXModel = newEnterUXModel
                        }
                        Cmd.none
                        ChainCmd.none
                        (let
                            ( funnelIdStr, maybeEventValue ) =
                                case actionData of
                                    Unlock ->
                                        ( "4b - "
                                        , Nothing
                                        )

                                    Enter enterInfo ->
                                        ( "8b - "
                                        , Just
                                            (enterInfo.amount
                                                |> TokenValue.toFloatWithWarning
                                                |> floor
                                            )
                                        )

                                    Exit ->
                                        ( "9b - "
                                        , Nothing
                                        )
                         in
                         [ CmdUp.gTag
                            (funnelIdStr ++ actionDataToString actionData ++ " tx signed ")
                            "funnel - tx"
                            (Eth.Utils.txHashToString txHash)
                            (maybeEventValue |> Maybe.withDefault 0)
                         ]
                        )

        TxStatusFetched trackedTxId actionData fetchResult ->
            case fetchResult of
                Err _ ->
                    -- Usually indicates the tx has not yet been mined. Ignore and do nothing.
                    justModelUpdate
                        prevModel

                Ok txReceipt ->
                    let
                        success =
                            -- the Maybe has to do with an Ethereum upgrade, far in the past, with which we need not concern ourselves
                            txReceipt.status |> Maybe.withDefault False

                        newSignedTxStatus =
                            if success then
                                Success

                            else
                                Failed

                        newTrackedTxs =
                            prevModel.trackedTxs
                                |> updateTrackedTxStatus trackedTxId
                                    (Signed txReceipt.hash newSignedTxStatus)

                        ( cmd, cmdUps ) =
                            case newSignedTxStatus of
                                Mining ->
                                    ( Cmd.none
                                    , []
                                    )

                                Success ->
                                    let
                                        ( funnelIdStr, maybeEventValue ) =
                                            case actionData of
                                                Unlock ->
                                                    ( "4c - "
                                                    , Nothing
                                                    )

                                                Enter enterInfo ->
                                                    ( "8c - "
                                                    , Just
                                                        (enterInfo.amount
                                                            |> TokenValue.toFloatWithWarning
                                                            |> floor
                                                        )
                                                    )

                                                Exit ->
                                                    ( "9c - "
                                                    , Nothing
                                                    )
                                    in
                                    ( let
                                        maybeBucketRefreshId =
                                            case actionData of
                                                Enter enterInfo ->
                                                    Just enterInfo.bucketId

                                                _ ->
                                                    Nothing
                                      in
                                      fetchStateUpdateInfoCmd
                                        (Wallet.userInfo prevModel.wallet)
                                        maybeBucketRefreshId
                                        prevModel.testMode
                                    , [ CmdUp.gTag
                                            (funnelIdStr ++ actionDataToString actionData ++ " tx success")
                                            "funnel - tx"
                                            (Eth.Utils.txHashToString txReceipt.hash)
                                            (maybeEventValue |> Maybe.withDefault 0)
                                      ]
                                    )

                                Failed ->
                                    ( Cmd.none
                                    , [ CmdUp.gTag
                                            (actionDataToString actionData ++ " tx failed")
                                            "funnel abort - tx"
                                            (Eth.Utils.txHashToString txReceipt.hash)
                                            0
                                      ]
                                    )
                    in
                    UpdateResult
                        { prevModel | trackedTxs = newTrackedTxs }
                        cmd
                        ChainCmd.none
                        cmdUps


runCmdDown : CmdDown -> Model -> UpdateResult
runCmdDown cmdDown prevModel =
    case cmdDown of
        CmdDown.UpdateWallet newWallet ->
            if prevModel.wallet == newWallet then
                justModelUpdate prevModel

            else
                let
                    newBucketSale =
                        prevModel.bucketSale
                            |> (Maybe.map << Result.map) clearBucketSaleExitInfo
                in
                UpdateResult
                    { prevModel
                        | wallet = verifyWalletCorrectNetwork newWallet prevModel.testMode
                        , bucketSale = newBucketSale
                        , extraUserInfo = Nothing
                    }
                    (fetchStateUpdateInfoCmd
                        (Wallet.userInfo newWallet)
                        (case newBucketSale of
                            Just (Ok bucketSale) ->
                                Just <|
                                    getFocusedBucketId
                                        bucketSale
                                        prevModel.bucketView
                                        prevModel.now
                                        prevModel.testMode

                            _ ->
                                Nothing
                        )
                        prevModel.testMode
                    )
                    ChainCmd.none
                    (case newWallet of
                        Wallet.NoneDetected ->
                            [ CmdUp.gTag
                                "no web3"
                                "funnel abort"
                                ""
                                0
                            ]

                        Wallet.OnlyNetwork _ ->
                            [ CmdUp.gTag
                                "1a - new wallet state - has web3"
                                "funnel"
                                ""
                                0
                            ]

                        Wallet.WrongNetwork ->
                            [ CmdUp.gTag
                                "1a - new wallet state - has web3"
                                "funnel"
                                ""
                                0
                            , CmdUp.gTag
                                "wrong network"
                                "funnel abort"
                                ""
                                0
                            ]

                        Wallet.Active userInfo ->
                            [ CmdUp.gTag
                                "1b - unlocked web3"
                                "funnel"
                                (Eth.Utils.addressToChecksumString userInfo.address)
                                0
                            ]
                    )

        CmdDown.UpdateReferral address ->
            UpdateResult
                { prevModel
                    | enterUXModel =
                        let
                            prevEnterUXModel =
                                prevModel.enterUXModel
                        in
                        { prevEnterUXModel
                            | referrer = Just address
                        }
                }
                Cmd.none
                ChainCmd.none
                []

        CmdDown.CloseAnyDropdownsOrModals ->
            justModelUpdate
                prevModel


toggleAssentForPoint : ( Int, Int ) -> ConfirmTosModel -> ConfirmTosModel
toggleAssentForPoint ( pageNum, pointNum ) prevTosModel =
    { prevTosModel
        | points =
            prevTosModel.points
                |> List.Extra.updateAt pageNum
                    (List.Extra.updateAt pointNum
                        (\point ->
                            { point
                                | maybeCheckedString =
                                    point.maybeCheckedString
                                        |> Maybe.map
                                            (\( checkboxText, isChecked ) ->
                                                ( checkboxText
                                                , not isChecked
                                                )
                                            )
                            }
                        )
                    )
    }


initBucketSale : TestMode -> Time.Posix -> Time.Posix -> Result String BucketSale
initBucketSale testMode saleStartTime now =
    if TimeHelpers.compare saleStartTime now == GT then
        Err <|
            "You're a little to early! The sale will start at noon UTC, June 19th."

    else
        Ok <|
            BucketSale
                saleStartTime
                (List.range 0 (Config.bucketSaleNumBuckets - 1)
                    |> List.map
                        (\id ->
                            BucketData
                                (TimeHelpers.add
                                    saleStartTime
                                    (TimeHelpers.mul
                                        (Config.bucketSaleBucketInterval testMode)
                                        id
                                    )
                                )
                                Nothing
                                Nothing
                        )
                )


fetchBucketDataCmd : Int -> Maybe UserInfo -> TestMode -> Cmd Msg
fetchBucketDataCmd id maybeUserInfo testMode =
    Cmd.batch
        [ fetchTotalValueEnteredCmd id testMode
        , case maybeUserInfo of
            Just userInfo ->
                fetchBucketUserBuyCmd id userInfo testMode

            Nothing ->
                Cmd.none
        ]


fetchTotalValueEnteredCmd : Int -> TestMode -> Cmd Msg
fetchTotalValueEnteredCmd id testMode =
    BucketSaleWrappers.getTotalValueEnteredForBucket
        testMode
        id
        (BucketValueEnteredFetched id)


fetchBucketUserBuyCmd : Int -> UserInfo -> TestMode -> Cmd Msg
fetchBucketUserBuyCmd id userInfo testMode =
    BucketSaleWrappers.getUserBuyForBucket
        testMode
        userInfo.address
        id
        (UserBuyFetched userInfo.address id)


fetchSaleStartTimestampCmd : TestMode -> Cmd Msg
fetchSaleStartTimestampCmd testMode =
    BucketSaleWrappers.getSaleStartTimestampCmd
        testMode
        SaleStartTimestampFetched


fetchTotalTokensExitedCmd : TestMode -> Cmd Msg
fetchTotalTokensExitedCmd testMode =
    BucketSaleWrappers.getTotalExitedTokens
        testMode
        TotalTokensExitedFetched


fetchStateUpdateInfoCmd : Maybe UserInfo -> Maybe Int -> TestMode -> Cmd Msg
fetchStateUpdateInfoCmd maybeUserInfo maybeBucketId testMode =
    BucketSaleWrappers.getStateUpdateInfo
        testMode
        (maybeUserInfo |> Maybe.map .address)
        (maybeBucketId
            |> Maybe.withDefault 0
        )
        StateUpdateInfoFetched


fetchFastGasPriceCmd : Cmd Msg
fetchFastGasPriceCmd =
    Http.get
        { url = Config.gasstationApiEndpoint
        , expect =
            Http.expectJson
                FetchedFastGasPrice
                fastGasPriceDecoder
        }


sendFeedbackCmd : ValidatedFeedbackInput -> Maybe String -> Cmd Msg
sendFeedbackCmd validatedFeedbackInput maybeDebugString =
    Http.request
        { method = "POST"
        , headers = []
        , url = Config.feedbackEndpointUrl
        , body =
            Http.jsonBody <| encodeFeedback validatedFeedbackInput
        , expect = Http.expectString FeedbackHttpResponse
        , timeout = Nothing
        , tracker = Nothing
        }


encodeFeedback : ValidatedFeedbackInput -> Json.Encode.Value
encodeFeedback feedback =
    Json.Encode.object
        [ ( "Id", Json.Encode.int 0 )
        , ( "Email", Json.Encode.string (feedback.email |> Maybe.withDefault "") )
        , ( "ProblemDescription", Json.Encode.string feedback.description )
        , ( "ModelData", Json.Encode.string (feedback.debugString |> Maybe.withDefault "") )
        ]


fastGasPriceDecoder : Json.Decode.Decoder BigInt
fastGasPriceDecoder =
    Json.Decode.field "fast" Json.Decode.float
        |> Json.Decode.map
            (\gweiTimes10 ->
                -- idk why, but ethgasstation returns units of gwei*10
                gweiTimes10 * 100000000
             -- multiply by (1 billion / 10) to get wei
            )
        |> Json.Decode.map floor
        |> Json.Decode.map BigInt.fromInt


clearBucketSaleExitInfo : BucketSale -> BucketSale
clearBucketSaleExitInfo =
    updateAllBuckets
        (\bucket ->
            { bucket | userBuy = Nothing }
        )


validateDaiInput : String -> Result String TokenValue
validateDaiInput input =
    case String.toFloat input of
        Just floatVal ->
            if floatVal <= 0 then
                Err "Value must be greater than 0"

            else
                Ok <| TokenValue.fromFloatWithWarning floatVal

        Nothing ->
            Err "Can't interpret that number"


trackNewTx : TrackedTx -> List TrackedTx -> ( Int, List TrackedTx )
trackNewTx newTrackedTx prevTrackedTxs =
    ( List.length prevTrackedTxs
    , List.append
        prevTrackedTxs
        [ newTrackedTx ]
    )


updateTrackedTxStatus : Int -> TxStatus -> List TrackedTx -> List TrackedTx
updateTrackedTxStatus id newStatus =
    List.Extra.updateAt id
        (\trackedTx ->
            { trackedTx | status = newStatus }
        )


locationCheckResultToJurisdictionStatus : Result Json.Decode.Error (Result String LocationInfo) -> JurisdictionCheckStatus
locationCheckResultToJurisdictionStatus decodeResult =
    decodeResult
        |> Result.map
            (\checkResult ->
                checkResult
                    |> Result.map
                        (\locationInfo ->
                            Checked <|
                                countryCodeToJurisdiction locationInfo.ipCode locationInfo.geoCode
                        )
                    |> Result.mapError
                        (\e ->
                            Error <|
                                "Location check failed: "
                                    ++ e
                        )
                    |> Result.Extra.merge
            )
        |> Result.mapError
            (\e -> Error <| "Location check response decode error: " ++ Json.Decode.errorToString e)
        |> Result.Extra.merge


countryCodeToJurisdiction : String -> String -> Jurisdiction
countryCodeToJurisdiction ipCode geoCode =
    let
        allowedJurisdiction =
            Set.fromList [ ipCode, geoCode ]
                |> Set.intersect forbiddenJurisdictionCodes
                |> Set.isEmpty
    in
    if allowedJurisdiction then
        JurisdictionsWeArentIntimidatedIntoExcluding

    else
        ForbiddenJurisdictions


locationCheckDecoder : Json.Decode.Decoder (Result String LocationInfo)
locationCheckDecoder =
    Json.Decode.oneOf
        [ Json.Decode.field "errorMessage" Json.Decode.string
            |> Json.Decode.map Err
        , locationInfoDecoder
            |> Json.Decode.map Ok
        ]


locationInfoDecoder : Json.Decode.Decoder LocationInfo
locationInfoDecoder =
    Json.Decode.map2
        LocationInfo
        (Json.Decode.field "ipCountry" Json.Decode.string)
        (Json.Decode.field "geoCountry" Json.Decode.string)


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Time.every 15000 <| always Refresh
        , Time.every 500 UpdateNow
        , Time.every (1000 * 60 * 10) <| always FetchFastGasPrice
        , locationCheckResult
            (Json.Decode.decodeValue locationCheckDecoder >> LocationCheckResult)
        ]


port beginLocationCheck : () -> Cmd msg


port locationCheckResult : (Json.Decode.Value -> msg) -> Sub msg


port addFryToMetaMask : () -> Cmd msg


tosLines : List (List ( List (Element Msg), Maybe String ))
tosLines =
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
                { url = "https://foundrydao.com/sale/terms/"
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
