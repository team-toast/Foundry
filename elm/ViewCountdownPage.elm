module ViewCountdownPage exposing (..)

import CmdUp
import Config
import Element exposing (Element)
import Element.Background
import Element.Border
import Element.Events
import Element.Font
import Eth.Types exposing (Address)
import Eth.Utils
import Helpers.Element as EH
import Helpers.Time as TimeHelpers
import Images
import Time
import TokenValue exposing (TokenValue)
import Types exposing (..)
import Wallet


view : Time.Posix -> Time.Posix -> Maybe Address -> Maybe TokenValue -> Element Msg
view now saleStartTime maybeUserAddress maybeUserBalance =
    Element.column
        [ Element.paddingXY 0 50
        , Element.width Element.fill
        , Element.spacing 40
        , Element.Font.color EH.white
        ]
        [ Element.el
            [ Element.Font.size 60
            , Element.centerX
            ]
          <|
            Element.text "Permafrost Sale"
        , Element.column
            [ Element.Font.size 40
            , Element.centerX
            , Element.spacing 15
            ]
            [ Element.el [ Element.centerX ] <| Element.text "starting in"
            , countdownTimerEl now saleStartTime
            ]
        , textBlurbEl maybeUserAddress maybeUserBalance
        ]


countdownTimerEl : Time.Posix -> Time.Posix -> Element Msg
countdownTimerEl now saleStartTime =
    Element.el
        [ Element.Font.size 30
        , Element.centerX
        ]
    <|
        Element.text <|
            countdownString <|
                TimeHelpers.sub saleStartTime now


countdownString : Time.Posix -> String
countdownString timeLeft =
    let
        hri =
            TimeHelpers.toHumanReadableInterval timeLeft
    in
    if hri.days > 0 then
        String.fromInt hri.days ++ "d " ++ String.fromInt hri.hours ++ "h " ++ String.fromInt hri.min ++ "m " ++ String.fromInt hri.sec ++ "s"

    else if hri.hours > 0 then
        String.fromInt hri.hours ++ "h " ++ String.fromInt hri.min ++ "m " ++ String.fromInt hri.sec ++ "s"

    else if hri.min > 0 then
        String.fromInt hri.min ++ "m " ++ String.fromInt hri.sec ++ "s"

    else
        String.fromInt hri.sec ++ "s"


textBlurbEl : Maybe Address -> Maybe TokenValue -> Element Msg
textBlurbEl maybeUserAddress maybeUserBalance =
    Element.column
        [ Element.Background.color <| Element.rgb 0.8 0.8 1
        , Element.Border.rounded 10
        , Element.padding 20
        , Element.width (Element.shrink |> Element.maximum 1200)
        , Element.centerX
        , Element.spacing 30
        , Element.Border.glow
            (Element.rgba 1 1 1 0.3)
            5
        , Element.Font.color <| EH.black
        , Element.Font.center
        ]
        (List.map
            (Element.paragraph
                [ Element.Font.size 30
                ]
            )
            [ [ Element.text "The permafrost sale will accept liquidity tokens for freshly minted FRY." ]
            , [ Element.text "This liquidity will then be "
              , Element.el [ Element.Font.bold ] <| Element.text "permanently locked"
              , Element.text ", resulting in \"unrugpullable\" liquidity."
              ]
            , [ Element.text "While you're waiting for this to start, you can get your liquidity tokens at "
              , Element.newTabLink
                [Element.Font.color EH.blue]
                { url = "https://pools.balancer.exchange/#/pool/0x5277a42ef95eca7637ffa9e69b65a12a089fe12b/"
                , label = Element.text "this balancer pool"
                }
                , Element.text ". "
              , case maybeUserAddress of
                    Just userAddress ->
                        Element.text <|
                            "Here's how much of these liquidity tokens your wallet ("
                                ++ Eth.Utils.addressToChecksumString userAddress
                                ++ ") shows:"

                    Nothing ->
                        Element.text "Connect your wallet to verify you have the right liquidity tokens."
              ]
            ]
            ++ [ tokenOutputEl (maybeUserAddress == Nothing) maybeUserBalance ]
        )


tokenOutputEl : Bool -> Maybe TokenValue -> Element Msg
tokenOutputEl showConnectButton maybeBalance =
    if showConnectButton then
        connectToWeb3Button

    else
        Element.column
            [ Element.spacing 10
            , Element.centerX
            ]
            [ case maybeBalance of
                Nothing ->
                    Element.el [ Element.centerX ] <|
                        Element.text "Loading balance..."

                Just balance ->
                    Element.row
                        [ Element.spacing 5
                        , Element.centerX
                        , Element.Font.size 50
                        ]
                        [ Element.text <|
                            TokenValue.toConciseString balance
                        , Images.enteringTokenSymbol
                            |> Images.toElement
                                [ Element.height <| Element.px 50 ]
                        ]
            ]


connectToWeb3Button : Element Msg
connectToWeb3Button =
    Element.el
        [ Element.width Element.fill
        , Element.padding 17
        , Element.Border.rounded 4
        , Element.Font.size 20
        , Element.Font.semiBold
        , Element.Font.center
        , Element.Background.color EH.softRed
        , Element.Font.color EH.white
        , Element.pointer
        , Element.Events.onClick <| CmdUp CmdUp.Web3Connect
        ]
        (Element.text "Connect to Wallet")
