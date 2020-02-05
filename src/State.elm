port module State exposing (init, subscriptions, update)

import List.Extra
import Browser
import Browser.Events
import Browser.Navigation
import BucketSale.State
import ChainCmd exposing (ChainCmd)
import CmdDown exposing (CmdDown)
import CmdUp exposing (CmdUp)
import CommonTypes exposing (..)
import Config
import Eth.Net
import Eth.Sentry.Tx as TxSentry
import Eth.Sentry.Wallet as WalletSentry
import Eth.Types exposing (Address)
import Eth.Utils
import Json.Decode
import Json.Encode
import Maybe.Extra
import Routing
import Time
import Types exposing (..)
import Url exposing (Url)
import UserNotice as UN exposing (UserNotice)
import Wallet


init : Flags -> Url -> Browser.Navigation.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        fullRoute =
            Routing.urlToFullRoute url

        ( wallet, cmdUps ) =
            if flags.networkId == 0 then
                ( Wallet.NoneDetected
                , [ CmdUp.gTag "web3 status" "profile" "none" 0 ]
                )

            else
                ( Wallet.OnlyNetwork <| Eth.Net.toNetworkId flags.networkId
                , [ CmdUp.gTag "web3 status" "profile" (Eth.Net.networkIdToString <| Eth.Net.toNetworkId flags.networkId) 0 ]
                )

        providerNotice =
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
            screenWidthToDisplayProfile flags.width

        ( maybeReferrer, maybeReferrerStoreCmd ) =
            let
                maybeReferrerFromStorage =
                    case flags.maybeReferralAddressString |> Maybe.map Eth.Utils.toAddress of
                        Nothing ->
                            Nothing

                        Just (Err errStr) ->
                            let
                                _ =
                                    Debug.log "Error decoding stored referrer address" errStr
                            in
                            Nothing

                        Just (Ok address) ->
                            Just address

                maybeReferrerFromUrl =
                    fullRoute.maybeReferrer
            in
            case maybeReferrerFromStorage of
                Just referrerFromStorage ->
                    ( Just referrerFromStorage, Cmd.none )

                Nothing ->
                    case maybeReferrerFromUrl of
                        Just referrerFromUrl ->
                            ( Just referrerFromUrl, storeNewReferrerCmd referrerFromUrl )

                        Nothing ->
                            ( Nothing, Cmd.none )

        newUrlCmd =
            let
                urlStringWithoutRefAddr =
                    Routing.routeToString
                        { fullRoute | maybeReferrer = Nothing }
            in
            if urlStringWithoutRefAddr /= Routing.routeToString fullRoute then
                Browser.Navigation.pushUrl key urlStringWithoutRefAddr

            else
                Cmd.none

        ( model, fromUrlCmd ) =
            { key = key
            , testMode = fullRoute.testing
            , wallet = wallet
            , userAddress = Nothing
            , now = Time.millisToPosix flags.nowInMillis
            , txSentry = txSentry
            , submodel = Home
            , pageRoute = Routing.Home
            , userNotices = []
            , dProfile = dProfile
            , maybeReferrer = maybeReferrer
            }
                |> updateFromPageRoute fullRoute.pageRoute
                |> runCmdUps cmdUps
    in
    ( model
        |> addUserNotices userNotices
    , Cmd.batch
        [ fromUrlCmd
        , maybeReferrerStoreCmd
        , newUrlCmd
        ]
    )


type alias EncryptedMessage =
    { encapsulatedKey : String
    , iv : String
    , tag : String
    , message : String
    }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        CmdUp cmdUp ->
            case cmdUp of
                CmdUp.Web3Connect ->
                    model
                        |> update ConnectToWeb3

                CmdUp.GotoRoute newRoute ->
                    model
                        |> update (GotoRoute newRoute)

                CmdUp.GTag gtag ->
                    ( model
                    , gTagOut (encodeGTag gtag)
                    )

                CmdUp.UserNotice userNotice ->
                    ( model |> addUserNotice userNotice
                    , gTagOut <|
                        encodeGTag <|
                            GTagData
                                "user notice"
                                "user notice"
                                userNotice.label
                                0
                    )

        Resize width _ ->
            { model
                | dProfile = screenWidthToDisplayProfile width
            }
                |> update NoOp

        LinkClicked urlRequest ->
            let
                cmd =
                    case urlRequest of
                        Browser.Internal url ->
                            Browser.Navigation.pushUrl model.key (Url.toString url)

                        Browser.External href ->
                            Browser.Navigation.load href
            in
            ( model, cmd )

        UrlChanged url ->
            model |> updateFromPageRoute (url |> Routing.urlToFullRoute |> .pageRoute)

        GotoRoute pageRoute ->
            model
                |> gotoPageRoute pageRoute
                |> Tuple.mapSecond
                    (\cmd ->
                        Cmd.batch
                            [ cmd
                            , gTagOut <|
                                encodeGTag <|
                                    GTagData
                                        "GotoRoute"
                                        "navigation"
                                        (Routing.routeToString
                                            (Routing.FullRoute model.testMode pageRoute Nothing)
                                        )
                                        0
                            , Browser.Navigation.pushUrl
                                model.key
                                (Routing.routeToString
                                    (Routing.FullRoute model.testMode pageRoute Nothing)
                                )
                            ]
                    )

        Tick newTime ->
            ( { model | now = newTime }, Cmd.none )

        ConnectToWeb3 ->
            case model.wallet of
                Wallet.NoneDetected ->
                    ( model |> addUserNotice UN.cantConnectNoWeb3
                    , Cmd.none
                    )

                _ ->
                    ( model
                    , connectToWeb3 ()
                    )

        WalletStatus walletSentry ->
            ( { model
                | userAddress = walletSentry.account
                , wallet = Wallet.OnlyNetwork walletSentry.networkId
              }
            , Cmd.none
            )

        BucketSaleMsg bucketSaleMsg ->
            case model.submodel of
                BucketSaleModel bucketSaleModel ->
                    let
                        updateResult =
                            BucketSale.State.update bucketSaleMsg bucketSaleModel

                        ( newTxSentry, chainCmd, userNotices ) =
                            ChainCmd.execute model.txSentry (ChainCmd.map BucketSaleMsg updateResult.chainCmd)
                    in
                    ( { model
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
                    ( model, Cmd.none )

        TxSentryMsg subMsg ->
            let
                ( newTxSentry, subCmd ) =
                    case model.txSentry of
                        Just txSentry ->
                            TxSentry.update subMsg txSentry
                                |> Tuple.mapFirst Just

                        Nothing ->
                            ( Nothing, Cmd.none )
            in
            ( { model | txSentry = newTxSentry }, subCmd )

        ClickHappened ->
            model |> runCmdDown CmdDown.CloseAnyDropdownsOrModals
        
        DismissNotice id ->
            ( { model
                | userNotices =
                    model.userNotices |> List.Extra.removeAt id
              }
            , Cmd.none
            )

        NoOp ->
            ( model, Cmd.none )

        Test s ->
            let
                _ =
                    Debug.log "test" s
            in
            ( model, Cmd.none )


runCmdUps : List (CmdUp.CmdUp Msg) -> ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
runCmdUps cmdUps ( model, prevCmd ) =
    List.foldl
        runCmdUp
        ( model, prevCmd )
        cmdUps


runCmdUp : CmdUp.CmdUp Msg -> ( Model, Cmd Msg ) -> ( Model, Cmd Msg )
runCmdUp cmdUp ( model, prevCmd ) =
    let
        ( newModel, newCmd ) =
            update
                (CmdUp cmdUp)
                model
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


updateFromPageRoute : Routing.PageRoute -> Model -> ( Model, Cmd Msg )
updateFromPageRoute pageRoute model =
    if model.pageRoute == pageRoute then
        ( model
        , Cmd.none
        )

    else
        gotoPageRoute pageRoute model


gotoPageRoute : Routing.PageRoute -> Model -> ( Model, Cmd Msg )
gotoPageRoute route prevModel =
    (case route of
        Routing.Home ->
            ( { prevModel | submodel = Home }
            , Cmd.none
            )

        Routing.Sale ->
            let
                ( bucketSaleModel, bucketSaleCmd ) =
                    BucketSale.State.init prevModel.maybeReferrer prevModel.testMode prevModel.wallet prevModel.now
            in
            ( { prevModel
                | submodel = BucketSaleModel bucketSaleModel
              }
            , Cmd.batch
                [ Cmd.map BucketSaleMsg bucketSaleCmd
                ]
            )

        Routing.NotFound ->
            ( prevModel |> addUserNotice UN.invalidUrl
            , Cmd.none
            )
    )
        |> Tuple.mapFirst
            (\model -> { model | pageRoute = route })


runCmdDown : CmdDown.CmdDown -> Model -> ( Model, Cmd Msg )
runCmdDown cmdDown prevModel =
    case prevModel.submodel of
        Home ->
            ( prevModel, Cmd.none )

        BucketSaleModel bucketSaleModel ->
            let
                updateResult =
                    bucketSaleModel |> BucketSale.State.runCmdDown cmdDown

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
        ([ Time.every 1000 Tick
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
        Home ->
            Sub.none

        BucketSaleModel bucketSaleModel ->
            Sub.map BucketSaleMsg <| BucketSale.State.subscriptions bucketSaleModel


port walletSentryPort : (Json.Decode.Value -> msg) -> Sub msg


port connectToWeb3 : () -> Cmd msg


port txOut : Json.Decode.Value -> Cmd msg


port txIn : (Json.Decode.Value -> msg) -> Sub msg


port gTagOut : Json.Decode.Value -> Cmd msg


port storeReferrerAddress : Json.Decode.Value -> Cmd msg
