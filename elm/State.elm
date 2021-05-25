port module State exposing (init, subscriptions, update)

import BigInt exposing (BigInt)
import Browser
import Browser.Events
import Browser.Navigation
import BucketSale.State as BucketSale exposing (log)
import BucketSale.Types as BucketTypes
import ChainCmd exposing (ChainCmd)
import CmdDown exposing (CmdDown)
import CmdUp exposing (CmdUp)
import Common.Types exposing (..)
import Config
import Contracts.BucketSale.Wrappers as BucketSaleWrappers
import Contracts.Wrappers as TokenWrappers
import ElementHelpers as EH
import Eth.Net
import Eth.Sentry.Tx as TxSentry
import Eth.Sentry.Wallet as WalletSentry
import Eth.Types exposing (Address)
import Eth.Utils
import Helpers.Time as TimeHelpers
import Json.Decode
import Json.Encode
import List.Extra
import Maybe.Extra
import Routing
import Time
import TokenValue exposing (TokenValue)
import Types exposing (..)
import Url exposing (Url)
import UserNotice as UN exposing (UserNotice)
import Wallet


init : Flags -> Url -> Browser.Navigation.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        fullRoute =
            Routing.urlToFullRoute url

        wallet =
            if flags.networkId == 0 then
                Wallet.NoneDetected

            else
                Wallet.OnlyNetwork <| Eth.Net.toNetworkId flags.networkId

        providerNotice =
            case fullRoute.pageRoute of
                _ ->
                    if wallet == Wallet.NoneDetected then
                        Just UN.noWeb3Provider

                    else
                        case Wallet.httpProvider wallet of
                            Nothing ->
                                Just UN.wrongWeb3Network

                            Just _ ->
                                Nothing

        userNotices =
            Maybe.Extra.values
                [ providerNotice ]

        txSentry =
            Wallet.httpProvider wallet
                |> Maybe.map
                    (\httpProvider ->
                        TxSentry.init ( txOut, txIn ) TxSentryMsg httpProvider
                    )

        dProfile =
            EH.screenWidthToDisplayProfile Config.displayProfileBreakpoint flags.width

        ( maybeReferrer, maybeReferrerStoreCmd ) =
            let
                ( maybeReferrerFromStorage, logCmd ) =
                    case flags.maybeReferralAddressString |> Maybe.map Eth.Utils.toAddress of
                        Nothing ->
                            ( Nothing, Cmd.none )

                        Just (Err errStr) ->
                            ( Nothing
                            , log <| "Error decoding stored referrer address:\n" ++ errStr
                            )

                        Just (Ok address) ->
                            ( Just address, Cmd.none )

                maybeReferrerFromUrl =
                    fullRoute.maybeReferrer
            in
            case maybeReferrerFromStorage of
                Just referrerFromStorage ->
                    ( Just referrerFromStorage, logCmd )

                Nothing ->
                    case maybeReferrerFromUrl of
                        Just referrerFromUrl ->
                            ( Just referrerFromUrl
                            , [ storeNewReferrerCmd referrerFromUrl
                              , logCmd
                              ]
                                |> Cmd.batch
                            )

                        Nothing ->
                            ( Nothing, logCmd )

        -- newUrlCmd =
        --     let
        --         urlStringWithoutRefAddr =
        --             Routing.routeToString
        --                 { fullRoute | maybeReferrer = Nothing }
        --     in
        --     if urlStringWithoutRefAddr /= Routing.routeToString fullRoute then
        --         Browser.Navigation.pushUrl key urlStringWithoutRefAddr
        --     else
        --         Cmd.none
        initSubmodel =
            LoadingSaleModel
                { loadingState = Loading
                , userBalance = Nothing
                }

        model =
            { key = key
            , testMode = fullRoute.testing
            , wallet = wallet
            , userAddress = Nothing
            , now = Time.millisToPosix flags.nowInMillis
            , txSentry = txSentry
            , submodel = initSubmodel
            , userNotices = []
            , dProfile = dProfile
            , maybeReferrer = maybeReferrer
            , displayMobileWarning = False

            --flags.width < 1024
            , nonRepeatingGTagsSent = []
            , cookieConsentGranted = flags.cookieConsent
            }

        -- |> updateFromPageRoute fullRoute.pageRoute
    in
    ( model
        |> addUserNotices userNotices
    , Cmd.batch
        [ maybeReferrerStoreCmd
        , fetchSaleStartTimestampCmd model.testMode

        -- , newUrlCmd
        ]
    )


type alias EncryptedMessage =
    { encapsulatedKey : String
    , iv : String
    , tag : String
    , message : String
    }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg prevModel =
    case msg of
        CmdUp cmdUp ->
            case cmdUp of
                CmdUp.Web3Connect ->
                    prevModel
                        |> update ConnectToWeb3

                -- CmdUp.GotoRoute newRoute ->
                --     prevModel
                --         |> update (GotoRoute newRoute)
                CmdUp.GTag gtag ->
                    ( prevModel
                    , gTagOut (encodeGTag gtag)
                    )

                CmdUp.Log str ->
                    ( prevModel
                    , log str
                    )

                CmdUp.NonRepeatingGTag gtag ->
                    let
                        alreadySent =
                            prevModel.nonRepeatingGTagsSent
                                |> List.any
                                    (\event ->
                                        event == gtag.event
                                    )
                    in
                    if alreadySent then
                        ( prevModel, Cmd.none )

                    else
                        ( { prevModel
                            | nonRepeatingGTagsSent =
                                prevModel.nonRepeatingGTagsSent
                                    |> List.append
                                        [ gtag.event ]
                          }
                        , gTagOut (encodeGTag gtag)
                        )

                CmdUp.UserNotice userNotice ->
                    ( prevModel |> addUserNotice userNotice
                    , gTagOut <|
                        encodeGTag <|
                            GTagData
                                "user notice"
                                "user notice"
                                userNotice.label
                                0
                    )

                CmdUp.NewReferralGenerated address ->
                    ( { prevModel
                        | maybeReferrer = Just address
                      }
                    , storeNewReferrerCmd address
                    )

        Resize width _ ->
            ( { prevModel
                | dProfile = EH.screenWidthToDisplayProfile Config.displayProfileBreakpoint width
              }
            , Cmd.none
            )

        LinkClicked urlRequest ->
            let
                cmd =
                    case urlRequest of
                        Browser.Internal url ->
                            Browser.Navigation.pushUrl prevModel.key (Url.toString url)

                        Browser.External href ->
                            Browser.Navigation.load href
            in
            ( prevModel, cmd )

        SaleStartTimestampFetched fetchResult ->
            case prevModel.submodel of
                LoadingSaleModel loadingSaleModel ->
                    case loadingSaleModel.loadingState of
                        Loading ->
                            case fetchResult of
                                Ok startTimestampBigInt ->
                                    let
                                        startTimestamp =
                                            TimeHelpers.secondsBigIntToPosixWithWarning startTimestampBigInt
                                    in
                                    if BigInt.compare startTimestampBigInt (BigInt.fromInt 0) == EQ then
                                        ( { prevModel
                                            | submodel =
                                                LoadingSaleModel <|
                                                    { loadingSaleModel
                                                        | loadingState = Error SaleNotDeployed -- A zero value indicates a dud deploy or not deployed
                                                    }
                                          }
                                        , Cmd.none
                                        )

                                    else
                                        case initBucketSale prevModel.testMode startTimestamp prevModel.now of
                                            Ok sale ->
                                                let
                                                    ( bucketSaleModel, submodelCmd ) =
                                                        BucketSale.init
                                                            prevModel.dProfile
                                                            sale
                                                            prevModel.maybeReferrer
                                                            prevModel.testMode
                                                            prevModel.wallet
                                                            prevModel.now
                                                in
                                                ( { prevModel
                                                    | submodel =
                                                        BucketSaleModel bucketSaleModel
                                                  }
                                                , Cmd.map BucketSaleMsg submodelCmd
                                                )

                                            Err loadError ->
                                                ( { prevModel
                                                    | submodel =
                                                        LoadingSaleModel
                                                            { loadingSaleModel
                                                                | loadingState = Error loadError
                                                            }
                                                  }
                                                , Cmd.none
                                                )

                                Err httpErr ->
                                    ( prevModel
                                    , log "http error when fetching sale startTime"
                                    )

                        Error _ ->
                            -- ignore, we shouldn't get another timestamp fetched
                            ( prevModel, Cmd.none )

                BucketSaleModel _ ->
                    -- ignore, we shouldn't get another timestamp fetched
                    ( prevModel, Cmd.none )

        FetchUserEnteringTokenBalance address ->
            ( prevModel
            , fetchUserEnteringTokenBalanceCmd prevModel.testMode address
            )

        UserEnteringTokenBalanceFetched address fetchResult ->
            case prevModel.submodel of
                LoadingSaleModel loadingSaleModel ->
                    case fetchResult of
                        Ok newBalance ->
                            { prevModel
                                | submodel =
                                    LoadingSaleModel <|
                                        { loadingSaleModel
                                            | userBalance = Just newBalance
                                        }
                            }
                                |> update
                                    (if not <| TokenValue.isZero newBalance then
                                        CmdUp <|
                                            CmdUp.nonRepeatingGTag
                                                ("0 - has " ++ Config.enteringTokenCurrencyLabel)
                                                "funnel"
                                                ""
                                                (newBalance |> TokenValue.toFloatWithWarning |> floor)

                                     else
                                        NoOp
                                    )

                        Err fetchError ->
                            ( prevModel
                                |> addUserNotice (UN.web3FetchError "token balance fetch" fetchError)
                            , Cmd.none
                            )

                BucketSaleModel _ ->
                    -- ignore, we shouldn't get another timestamp fetched
                    ( prevModel, Cmd.none )

        -- UrlChanged url ->
        --     prevModel |> updateFromPageRoute (url |> Routing.urlToFullRoute |> .pageRoute)
        -- GotoRoute pageRoute ->
        --     prevModel
        --         |> gotoPageRoute pageRoute
        --         |> Tuple.mapSecond
        --             (\cmd ->
        --                 Cmd.batch
        --                     [ cmd
        --                     , Browser.Navigation.pushUrl
        --                         prevModel.key
        --                         (Routing.routeToString
        --                             (Routing.FullRoute prevModel.testMode pageRoute Nothing)
        --                         )
        --                     ]
        --             )
        UpdateNow newNow ->
            let
                modelWithUpdatedNow =
                    { prevModel | now = newNow }
            in
            case prevModel.submodel of
                LoadingSaleModel loadingSaleModel ->
                    case loadingSaleModel.loadingState of
                        Error (SaleNotStarted startTime) ->
                            case initBucketSale prevModel.testMode startTime newNow of
                                Ok bucketSale ->
                                    let
                                        ( bucketSaleModel, bucketSaleCmd ) =
                                            BucketSale.init
                                                prevModel.dProfile
                                                bucketSale
                                                prevModel.maybeReferrer
                                                prevModel.testMode
                                                prevModel.wallet
                                                newNow
                                    in
                                    ( { modelWithUpdatedNow
                                        | submodel = BucketSaleModel bucketSaleModel
                                      }
                                    , Cmd.map BucketSaleMsg bucketSaleCmd
                                    )

                                Err _ ->
                                    ( modelWithUpdatedNow
                                    , Cmd.none
                                    )

                        _ ->
                            ( modelWithUpdatedNow, Cmd.none )

                _ ->
                    ( modelWithUpdatedNow, Cmd.none )

        ConnectToWeb3 ->
            case prevModel.wallet of
                Wallet.NoneDetected ->
                    ( prevModel |> addUserNotice UN.cantConnectNoWeb3
                    , Cmd.none
                    )

                _ ->
                    ( prevModel
                    , connectToWeb3 ()
                    )

        WalletStatus walletSentry ->
            let
                ( newWallet, foundWeb3Account ) =
                    case walletSentry.account of
                        Just address ->
                            ( Wallet.Active <|
                                UserInfo
                                    walletSentry.networkId
                                    address
                            , True
                            )

                        Nothing ->
                            ( Wallet.OnlyNetwork walletSentry.networkId
                            , False
                            )

                newModel =
                    { prevModel
                        | userAddress = walletSentry.account
                        , wallet = newWallet
                    }
                        |> (if foundWeb3Account then
                                removeUserNoticesByLabel UN.noWeb3Account.label

                            else
                                addUserNotice UN.noWeb3Account
                           )
            in
            if newWallet /= prevModel.wallet then
                newModel
                    |> runCmdDown (CmdDown.UpdateWallet newWallet)
                    |> (\( newModel_, updateWalletCmd ) ->
                            ( newModel_
                            , Cmd.batch
                                [ updateWalletCmd
                                , gTagOut <|
                                    encodeGTag <|
                                        GTagData
                                            "new wallet"
                                            "funnel"
                                            (newWallet
                                                |> Wallet.userInfo
                                                |> Maybe.map .address
                                                |> Maybe.map Eth.Utils.addressToString
                                                |> Maybe.withDefault "none"
                                            )
                                            0
                                ]
                            )
                       )

            else
                ( newModel, Cmd.none )

        BucketSaleMsg bucketSaleMsg ->
            case prevModel.submodel of
                BucketSaleModel bucketSaleModel ->
                    let
                        updateResult =
                            BucketSale.update bucketSaleMsg bucketSaleModel

                        ( newTxSentry, chainCmd, userNotices ) =
                            ChainCmd.execute prevModel.txSentry (ChainCmd.map BucketSaleMsg updateResult.chainCmd)
                    in
                    ( { prevModel
                        | submodel = BucketSaleModel updateResult.model
                        , txSentry = newTxSentry
                      }
                    , Cmd.batch
                        [ Cmd.map BucketSaleMsg updateResult.cmd
                        , chainCmd
                        ]
                    )
                        |> runCmdUps
                            (CmdUp.mapList BucketSaleMsg updateResult.cmdUps
                                ++ List.map CmdUp.UserNotice userNotices
                            )

                _ ->
                    ( prevModel, Cmd.none )

        TxSentryMsg subMsg ->
            let
                ( newTxSentry, subCmd ) =
                    case prevModel.txSentry of
                        Just txSentry ->
                            TxSentry.update subMsg txSentry
                                |> Tuple.mapFirst Just

                        Nothing ->
                            ( Nothing, Cmd.none )
            in
            ( { prevModel | txSentry = newTxSentry }, subCmd )

        CookieConsentGranted ->
            ( { prevModel
                | cookieConsentGranted = True
              }
            , Cmd.batch
                [ consentToCookies ()
                , gTagOut <|
                    encodeGTag <|
                        GTagData
                            "accept cookies"
                            ""
                            ""
                            0
                ]
            )

        ClickHappened ->
            prevModel |> runCmdDown CmdDown.CloseAnyDropdownsOrModals

        DismissNotice id ->
            ( { prevModel
                | userNotices =
                    prevModel.userNotices |> List.Extra.removeAt id
              }
            , Cmd.none
            )

        NoOp ->
            ( prevModel, Cmd.none )

        Test s ->
            ( prevModel, log <| "test: " ++ s )


initBucketSale : TestMode -> Time.Posix -> Time.Posix -> Result BucketSaleError BucketTypes.BucketSale
initBucketSale testMode saleStartTime now =
    if TimeHelpers.compare saleStartTime now == GT then
        Err <| SaleNotStarted <| saleStartTime

    else
        Ok <|
            BucketTypes.BucketSale
                saleStartTime
                (List.range 0 (Config.bucketSaleNumBuckets - 1)
                    |> List.map
                        (\id ->
                            BucketTypes.BucketData
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


runCmdUps : List (CmdUp.CmdUp Msg) -> ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
runCmdUps cmdUps ( prevModel, prevCmd ) =
    List.foldl
        runCmdUp
        ( prevModel, prevCmd )
        cmdUps


runCmdUp : CmdUp.CmdUp Msg -> ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
runCmdUp cmdUp ( prevModel, prevCmd ) =
    let
        ( newModel, newCmd ) =
            update
                (CmdUp cmdUp)
                prevModel
    in
    ( newModel
    , Cmd.batch
        [ prevCmd
        , newCmd
        ]
    )


addUserNotices : List (UserNotice Msg) -> Model -> Model
addUserNotices userNotices prevModel =
    List.foldl
        addUserNotice
        prevModel
        userNotices


addUserNotice : UserNotice Msg -> Model -> Model
addUserNotice userNotice prevModel =
    if List.member userNotice prevModel.userNotices then
        prevModel

    else
        { prevModel
            | userNotices =
                List.append
                    prevModel.userNotices
                    [ userNotice ]
        }


removeUserNoticesByLabel : String -> Model -> Model
removeUserNoticesByLabel label prevModel =
    { prevModel
        | userNotices =
            prevModel.userNotices
                |> List.filter
                    (.label >> (/=) label)
    }


encodeGTag : GTagData -> Json.Decode.Value
encodeGTag gtag =
    Json.Encode.object
        [ ( "event", Json.Encode.string gtag.event )
        , ( "category", Json.Encode.string gtag.category )
        , ( "label", Json.Encode.string gtag.label )
        , ( "value", Json.Encode.int gtag.value )
        ]


encodeGenPrivkeyArgs : Address -> String -> Json.Decode.Value
encodeGenPrivkeyArgs address signMsg =
    Json.Encode.object
        [ ( "address", Json.Encode.string <| Eth.Utils.addressToString address )
        , ( "signSeedMsg", Json.Encode.string signMsg )
        ]



-- updateFromPageRoute : Routing.PageRoute -> Model -> ( Model, Cmd Msg )
-- updateFromPageRoute pageRoute prevModel =
--     if prevModel.pageRoute == pageRoute then
--         ( prevModel
--         , Cmd.none
--         )
--     else
--         gotoPageRoute pageRoute prevModel
-- gotoPageRoute : Routing.PageRoute -> Model -> ( Model, Cmd Msg )
-- gotoPageRoute route prevModel =
--     (case route of
--         Routing.Sale ->
--             let
--                 ( bucketSaleModel, bucketSaleCmd ) =
--                     BucketSale.State.init prevModel.maybeReferrer prevModel.testMode prevModel.wallet prevModel.now
--             in
--             ( { prevModel
--                 | submodel = BucketSaleModel bucketSaleModel
--               }
--             , Cmd.batch
--                 [ Cmd.map BucketSaleMsg bucketSaleCmd
--                 ]
--             )
--         Routing.NotFound ->
--             ( prevModel |> addUserNotice UN.invalidUrl
--             , Cmd.none
--             )
--     )
--         |> Tuple.mapFirst
--             (\model -> { model | pageRoute = route })


runCmdDown : CmdDown.CmdDown -> Model -> ( Model, Cmd Msg )
runCmdDown cmdDown prevModel =
    case prevModel.submodel of
        LoadingSaleModel bucketSaleLoadingModel ->
            case cmdDown of
                CmdDown.UpdateWallet newWallet ->
                    let
                        newSubmodel =
                            LoadingSaleModel <|
                                { bucketSaleLoadingModel
                                    | userBalance = Nothing
                                }

                        cmd =
                            case Wallet.userInfo newWallet of
                                Just userInfo ->
                                    fetchUserEnteringTokenBalanceCmd
                                        prevModel.testMode
                                        userInfo.address

                                Nothing ->
                                    Cmd.none
                    in
                    ( { prevModel
                        | submodel = newSubmodel
                      }
                    , cmd
                    )

                CmdDown.CloseAnyDropdownsOrModals ->
                    ( prevModel, Cmd.none )

        BucketSaleModel bucketSaleModel ->
            let
                updateResult =
                    bucketSaleModel |> BucketSale.runCmdDown cmdDown

                ( newTxSentry, chainCmd, userNotices ) =
                    ChainCmd.execute prevModel.txSentry (ChainCmd.map BucketSaleMsg updateResult.chainCmd)
            in
            ( { prevModel
                | submodel = BucketSaleModel updateResult.model
                , txSentry = newTxSentry
              }
            , Cmd.batch
                [ Cmd.map BucketSaleMsg updateResult.cmd
                , chainCmd
                ]
            )
                |> runCmdUps
                    (CmdUp.mapList BucketSaleMsg updateResult.cmdUps
                        ++ List.map CmdUp.UserNotice userNotices
                    )


fetchUserEnteringTokenBalanceCmd : TestMode -> Address -> Cmd Msg
fetchUserEnteringTokenBalanceCmd testMode address =
    TokenWrappers.getBalanceCmd
        testMode
        address
        (UserEnteringTokenBalanceFetched address)


fetchSaleStartTimestampCmd : TestMode -> Cmd Msg
fetchSaleStartTimestampCmd testMode =
    BucketSaleWrappers.getSaleStartTimestampCmd
        testMode
        SaleStartTimestampFetched


storeNewReferrerCmd : Address -> Cmd Msg
storeNewReferrerCmd refAddress =
    storeReferrerAddress <|
        Json.Encode.string (Eth.Utils.addressToString refAddress)


subscriptions : Model -> Sub Msg
subscriptions model =
    let
        failedWalletDecodeToMsg : String -> Msg
        failedWalletDecodeToMsg =
            UN.walletError >> CmdUp.UserNotice >> CmdUp
    in
    Sub.batch
        ([ Time.every 1000 UpdateNow
         , walletSentryPort (WalletSentry.decodeToMsg failedWalletDecodeToMsg WalletStatus)
         , Maybe.map TxSentry.listen model.txSentry
            |> Maybe.withDefault Sub.none
         , Browser.Events.onResize Resize
         ]
            ++ [ submodelSubscriptions model ]
        )


submodelSubscriptions : Model -> Sub Msg
submodelSubscriptions model =
    case model.submodel of
        LoadingSaleModel bucketSaleLoadingModel ->
            case Wallet.userInfo model.wallet of
                Just userInfo ->
                    Time.every 5000 <| always (FetchUserEnteringTokenBalance userInfo.address)

                Nothing ->
                    Sub.none

        BucketSaleModel bucketSaleModel ->
            Sub.map BucketSaleMsg <| BucketSale.subscriptions bucketSaleModel


port walletSentryPort : (Json.Decode.Value -> msg) -> Sub msg


port connectToWeb3 : () -> Cmd msg


port txOut : Json.Decode.Value -> Cmd msg


port txIn : (Json.Decode.Value -> msg) -> Sub msg


port gTagOut : Json.Decode.Value -> Cmd msg


port storeReferrerAddress : Json.Decode.Value -> Cmd msg


port consentToCookies : () -> Cmd msg
