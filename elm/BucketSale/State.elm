port module BucketSale.State exposing (init, runCmdDown, subscriptions, update)

import BigInt exposing (BigInt)
import BucketSale.Types exposing (..)
import ChainCmd exposing (ChainCmd)
import CmdDown exposing (CmdDown)
import CmdUp exposing (CmdUp)
import CommonTypes exposing (..)
import Config
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
import Helpers.Time as TimeHelpers
import Http
import Json.Decode
import Json.Decode.Extra
import List.Extra
import Maybe.Extra
import Result.Extra
import Task
import Time
import TokenValue exposing (TokenValue)
import Utils
import Wallet


init : Maybe Address -> TestMode -> Wallet.State -> Time.Posix -> ( Model, Cmd Msg )
init maybeReferrer testMode wallet now =
    ( { wallet = verifyWalletCorrectNetwork wallet testMode
      , testMode = testMode
      , now = now
      , timezone = Nothing
      , fastGasPrice = Nothing
      , saleStartTime = Nothing
      , bucketSale = Nothing
      , totalTokensExited = Nothing
      , userFryBalance = Nothing
      , bucketView = ViewCurrent
      , jurisdictionCheckStatus = WaitingForClick
      , enterUXModel = initEnterUXModel maybeReferrer
      , userExitInfo = Nothing
      , trackedTxs = []
      , confirmTosModel = initConfirmTosModel
      , enterInfoToConfirm = Nothing
      , showReferralModal = False
      }
    , Cmd.batch
        ([ fetchSaleStartTimestampCmd testMode
         , fetchTotalTokensExitedCmd testMode
         , fetchFastGasPriceCmd
         , Task.perform TimezoneGot Time.here
         ]
            ++ (case Wallet.userInfo wallet of
                    Just userInfo ->
                        [ fetchUserExitInfoCmd userInfo testMode
                        , fetchUserAllowanceForSaleCmd userInfo testMode
                        , fetchUserFryBalanceCmd userInfo testMode
                        ]

                    Nothing ->
                        []
               )
        )
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
    , allowance = Nothing
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
                fetchUserInfoCmds =
                    Cmd.batch <|
                        (Maybe.map
                            (\userInfo ->
                                [ fetchUserExitInfoCmd userInfo prevModel.testMode
                                , fetchUserAllowanceForSaleCmd userInfo prevModel.testMode
                                , fetchUserFryBalanceCmd userInfo prevModel.testMode
                                ]
                            )
                            (Wallet.userInfo prevModel.wallet)
                            |> Maybe.withDefault []
                        )

                bucketDataCmd =
                    prevModel.bucketSale
                        |> (Maybe.map << Result.map)
                            (\bucketSale ->
                                fetchBucketDataCmd
                                    (getFocusedBucketId
                                        bucketSale
                                        prevModel.bucketView
                                        prevModel.now
                                        prevModel.testMode
                                    )
                                    (Wallet.userInfo prevModel.wallet)
                                    prevModel.testMode
                            )
                        |> Maybe.withDefault (Ok Cmd.none)
                        |> Result.withDefault Cmd.none
            in
            UpdateResult
                prevModel
                (Cmd.batch
                    [ fetchTotalTokensExitedCmd prevModel.testMode
                    , bucketDataCmd
                    , fetchUserInfoCmds
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
            justModelUpdate
                { prevModel
                    | confirmTosModel =
                        prevModel.confirmTosModel
                            |> toggleAssentForPoint pointRef
                }

        VerifyJurisdictionClicked ->
            UpdateResult
                { prevModel
                    | jurisdictionCheckStatus = Checking
                }
                (beginLocationCheck ())
                ChainCmd.none
                [ CmdUp.gTag "verify jurisdiction" "funnel" "clicked" 0 ]

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
                [ CmdUp.gTag
                    "verify jurisdiction"
                    "funnel"
                    ("result: "
                        ++ (case jurisdictionCheckStatus of
                                WaitingForClick ->
                                    "WaitingForClick"

                                Checking ->
                                    "Checking"

                                Checked jurisdiction ->
                                    "Checked: "
                                        ++ (case jurisdiction of
                                                USA ->
                                                    "USA"

                                                _ ->
                                                    "Allowed"
                                           )

                                Error error ->
                                    "Error: " ++ error
                           )
                    )
                    0
                ]

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

        UserExitInfoFetched userAddress fetchResult ->
            if (Wallet.userInfo prevModel.wallet |> Maybe.map .address) /= Just userAddress then
                justModelUpdate prevModel

            else
                case fetchResult of
                    Err httpErr ->
                        let
                            _ =
                                Debug.log "http error when fetching userExitInfo" ( userAddress, httpErr )
                        in
                        justModelUpdate prevModel

                    Ok Nothing ->
                        let
                            _ =
                                Debug.log "Query contract returned an invalid result" userAddress
                        in
                        justModelUpdate prevModel

                    Ok (Just exitInfo) ->
                        justModelUpdate
                            { prevModel
                                | userExitInfo = Just exitInfo
                            }

        UserFryBalanceFetched userAddress fetchResult ->
            if (Wallet.userInfo prevModel.wallet |> Maybe.map .address) /= Just userAddress then
                justModelUpdate prevModel

            else
                case fetchResult of
                    Err httpErr ->
                        let
                            _ =
                                Debug.log "http error when fetching userFryBalance" ( userAddress, httpErr )
                        in
                        justModelUpdate prevModel

                    Ok userFryBalance ->
                        justModelUpdate
                            { prevModel
                                | userFryBalance = Just userFryBalance
                            }

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

        AllowanceFetched fetchResult ->
            case fetchResult of
                Err httpErr ->
                    let
                        _ =
                            Debug.log "http error when fetching user allowance" httpErr
                    in
                    justModelUpdate prevModel

                Ok newAllowance ->
                    justModelUpdate
                        { prevModel
                            | enterUXModel =
                                let
                                    oldEnterUXModel =
                                        prevModel.enterUXModel
                                in
                                { oldEnterUXModel
                                    | allowance = Just <| TokenValue.tokenValue newAllowance
                                }
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
                        [ CmdUp.gTag "focus to bucket" "navigation" "" bucketId ]

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
                [ CmdUp.gTag "dai input changed" "funnel" input 0 ]

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
                                Nothing
                                Unlock
                                Signing
                            )

                chainCmd =
                    let
                        customSend =
                            { onMined = Just ( TxMined trackedTxId Unlock, Nothing )
                            , onSign = Just <| TxSigned trackedTxId Unlock
                            , onBroadcast = Just <| TxBroadcast trackedTxId Unlock
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
                [ CmdUp.gTag "unlock clicked" "funnel" "" 0 ]

        EnterButtonClicked enterInfo ->
            UpdateResult
                { prevModel
                    | enterInfoToConfirm = Just enterInfo
                }
                Cmd.none
                ChainCmd.none
                [ CmdUp.gTag "enter clicked" "funnel" (TokenValue.toFloatString Nothing enterInfo.amount) 0 ]

        CancelClicked ->
            UpdateResult
                { prevModel
                    | enterInfoToConfirm = Nothing
                }
                Cmd.none
                ChainCmd.none
                [ CmdUp.gTag "tos aborted" "funnel abort" "" 0 ]

        ConfirmClicked enterInfo ->
            let
                actionData =
                    Enter enterInfo

                ( trackedTxId, newTrackedTxs ) =
                    prevModel.trackedTxs
                        |> trackNewTx
                            (TrackedTx
                                Nothing
                                actionData
                                Signing
                            )

                chainCmd =
                    let
                        customSend =
                            { onMined = Just ( TxMined trackedTxId actionData, Nothing )
                            , onSign = Just <| TxSigned trackedTxId actionData
                            , onBroadcast = Just <| TxBroadcast trackedTxId actionData
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
                [ CmdUp.gTag "confirm clicked" "funnel" (TokenValue.toFloatString Nothing enterInfo.amount) 0 ]

        ClaimClicked userInfo exitInfo ->
            let
                ( trackedTxId, newTrackedTxs ) =
                    prevModel.trackedTxs
                        |> trackNewTx
                            (TrackedTx
                                Nothing
                                Exit
                                Signing
                            )

                chainCmd =
                    let
                        customSend =
                            { onMined = Just ( TxMined trackedTxId Exit, Nothing )
                            , onSign = Just <| TxSigned trackedTxId Exit
                            , onBroadcast = Just <| TxBroadcast trackedTxId Exit
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
                            ("tx sign error / " ++ actionDataToString actionData)
                            "tx lifecycle"
                            errStr
                            0
                        ]

                Ok txHash ->
                    let
                        newTrackedTxs =
                            prevModel.trackedTxs
                                |> updateTrackedTxStatus trackedTxId Mining

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
                        [ CmdUp.gTag
                            ("tx sign success / " ++ actionDataToString actionData)
                            "tx lifecycle"
                            (Eth.Utils.txHashToString txHash)
                            0
                        ]

        TxBroadcast trackedTxId actionData txResult ->
            case txResult of
                Err errStr ->
                    let
                        _ =
                            Debug.log "Error broadcasting tx" ( actionData, errStr )
                    in
                    UpdateResult
                        { prevModel
                            | trackedTxs =
                                prevModel.trackedTxs
                                    |> updateTrackedTxStatus trackedTxId Failed
                        }
                        Cmd.none
                        ChainCmd.none
                        [ CmdUp.gTag
                            ("tx broadcast error / " ++ actionDataToString actionData)
                            "tx lifecycle"
                            errStr
                            0
                        ]

                Ok tx ->
                    let
                        newTrackedTxs =
                            prevModel.trackedTxs
                                |> updateTrackedTxStatus trackedTxId Mining
                    in
                    UpdateResult
                        { prevModel
                            | trackedTxs = newTrackedTxs
                        }
                        Cmd.none
                        ChainCmd.none
                        [ CmdUp.gTag
                            ("tx broadcast success / " ++ actionDataToString actionData)
                            "tx lifecycle"
                            (Eth.Utils.txHashToString tx.hash)
                            0
                        ]

        TxMined trackedTxId actionData txReceiptResult ->
            case txReceiptResult of
                Err errStr ->
                    let
                        _ =
                            Debug.log "Error mining tx" ( actionData, errStr )
                    in
                    UpdateResult
                        { prevModel
                            | trackedTxs =
                                prevModel.trackedTxs
                                    |> updateTrackedTxStatus trackedTxId Failed
                        }
                        Cmd.none
                        ChainCmd.none
                        [ CmdUp.gTag
                            ("tx mine error / " ++ actionDataToString actionData)
                            "tx lifecycle"
                            errStr
                            0
                        ]

                Ok txReceipt ->
                    let
                        newTrackedTxs =
                            prevModel.trackedTxs
                                |> updateTrackedTxStatus trackedTxId Mined

                        cmd =
                            case ( actionData, Wallet.userInfo prevModel.wallet ) of
                                ( Exit, Just userInfo ) ->
                                    Cmd.batch
                                        [ fetchUserExitInfoCmd
                                            userInfo
                                            prevModel.testMode
                                        , fetchUserFryBalanceCmd
                                            userInfo
                                            prevModel.testMode
                                        ]

                                ( Enter enterInfo, _ ) ->
                                    case prevModel.bucketSale of
                                        Just (Ok bucketSale) ->
                                            fetchBucketDataCmd
                                                enterInfo.bucketId
                                                (Wallet.userInfo prevModel.wallet)
                                                prevModel.testMode

                                        _ ->
                                            Cmd.none

                                _ ->
                                    Cmd.none
                    in
                    UpdateResult
                        { prevModel
                            | trackedTxs = newTrackedTxs
                        }
                        cmd
                        ChainCmd.none
                        [ CmdUp.gTag
                            ("tx sign success / " ++ actionDataToString actionData)
                            "tx lifecycle"
                            (Eth.Utils.txHashToString txReceipt.hash)
                            0
                        ]
                        


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


fetchUserExitInfoCmd : UserInfo -> TestMode -> Cmd Msg
fetchUserExitInfoCmd userInfo testMode =
    BucketSaleWrappers.getUserExitInfo
        testMode
        userInfo.address
        (UserExitInfoFetched userInfo.address)


fetchUserAllowanceForSaleCmd : UserInfo -> TestMode -> Cmd Msg
fetchUserAllowanceForSaleCmd userInfo testMode =
    Contracts.Wrappers.getAllowanceCmd
        testMode
        userInfo.address
        (Config.bucketSaleAddress testMode)
        AllowanceFetched


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


fetchUserFryBalanceCmd : UserInfo -> TestMode -> Cmd Msg
fetchUserFryBalanceCmd userInfo testMode =
    BucketSaleWrappers.getFryBalance
        testMode
        userInfo.address
        (UserFryBalanceFetched userInfo.address)


fetchFastGasPriceCmd : Cmd Msg
fetchFastGasPriceCmd =
    Http.get
        { url = Config.gasstationApiEndpoint
        , expect =
            Http.expectJson
                FetchedFastGasPrice
                fastGasPriceDecoder
        }


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


runCmdDown : CmdDown -> Model -> UpdateResult
runCmdDown cmdDown prevModel =
    case cmdDown of
        CmdDown.UpdateWallet newWallet ->
            if prevModel.wallet == newWallet then
                justModelUpdate prevModel

            else
                let
                    newBucketSale =
                        (Maybe.map << Result.map)
                            clearBucketSaleExitInfo
                            prevModel.bucketSale
                in
                UpdateResult
                    { prevModel
                        | wallet = verifyWalletCorrectNetwork newWallet prevModel.testMode
                        , bucketSale = newBucketSale
                        , userFryBalance = Nothing
                        , userExitInfo = Nothing
                        , enterUXModel =
                            let
                                oldEnterUXModel =
                                    prevModel.enterUXModel
                            in
                            { oldEnterUXModel
                                | allowance = Nothing
                            }
                    }
                    (case ( Wallet.userInfo newWallet, newBucketSale ) of
                        ( Just userInfo, Just (Ok bucketSale) ) ->
                            Cmd.batch
                                [ fetchUserAllowanceForSaleCmd
                                    userInfo
                                    prevModel.testMode
                                , fetchUserFryBalanceCmd
                                    userInfo
                                    prevModel.testMode
                                , fetchBucketDataCmd
                                    (getFocusedBucketId
                                        bucketSale
                                        prevModel.bucketView
                                        prevModel.now
                                        prevModel.testMode
                                    )
                                    (Just userInfo)
                                    prevModel.testMode
                                , fetchUserExitInfoCmd
                                    userInfo
                                    prevModel.testMode
                                ]

                        _ ->
                            Cmd.none
                    )
                    ChainCmd.none
                    []

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


locationCheckResultToJurisdictionStatus : Result Json.Decode.Error (Result String LocationInfo) -> JurisdictionCheckStatus
locationCheckResultToJurisdictionStatus decodeResult =
    decodeResult
        |> Result.map
            (\checkResult ->
                checkResult
                    |> Result.map
                        (\locationInfo ->
                            case locationInfo.countryInfo of
                                Matching countryCode ->
                                    Checked <|
                                        countryCodeToJurisdiction countryCode

                                NotMatching ->
                                    Error
                                        "Geolocation and IP analysis give different country codes."
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


countryCodeToJurisdiction : String -> Jurisdiction
countryCodeToJurisdiction code =
    if code == "US" then
        USA

    else
        JurisdictionsWeArentIntimidatedIntoExcluding


locationCheckDecoder : Json.Decode.Decoder (Result String LocationInfo)
locationCheckDecoder =
    Json.Decode.oneOf
        [ Json.Decode.map Err <|
            Json.Decode.field "ErrorMessage" Json.Decode.string
        , Json.Decode.map Ok locationInfoDecoder
        ]


locationInfoDecoder : Json.Decode.Decoder LocationInfo
locationInfoDecoder =
    Json.Decode.map2
        LocationInfo
        countryInfoDecoder
        (Json.Decode.field "kmDistance" Json.Decode.float)


countryInfoDecoder : Json.Decode.Decoder CountryInfo
countryInfoDecoder =
    Json.Decode.map2
        (\countryMatches countryString ->
            if countryMatches then
                Matching countryString

            else
                NotMatching
        )
        (Json.Decode.field "countryMatches" Json.Decode.bool)
        (Json.Decode.field "country" Json.Decode.string)


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
    , [ ( List.singleton <| Element.text "Entering DAI into the sale is irrevocable, even if the bucket has not yet concluded."
        , Just "I understand."
        )
      , ( List.singleton <| Element.text "US citizens and residents are strictly prohibited from this sale."
        , Just "I am not a citizen of the USA."
        )
      ]
    ]
