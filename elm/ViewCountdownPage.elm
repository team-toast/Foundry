module ViewCountdownPage exposing (..)

import CmdUp
import CommonTypes exposing (..)
import Config
import Element exposing (Element)
import Element.Background
import Element.Border
import Element.Events
import Element.Font
import Embed.Youtube
import Embed.Youtube.Attributes
import Eth.Types exposing (Address)
import Eth.Utils
import Helpers.Element as EH
import Helpers.Time as TimeHelpers
import Images
import Time
import TokenValue exposing (TokenValue)
import Types exposing (..)
import Wallet


view : Time.Posix -> Time.Posix -> Maybe Address -> Maybe TokenValue -> DisplayProfile -> Element Msg
view now saleStartTime maybeUserAddress maybeUserBalance dProfile =
    Element.column
        [ responsiveVal dProfile
            (Element.paddingXY 0 50)
            (Element.paddingXY 0 0)
        , Element.width Element.fill
        , Element.spacing 40
        ]
        [ viewMainBlock now saleStartTime maybeUserAddress maybeUserBalance dProfile
        ]


viewMainBlock : Time.Posix -> Time.Posix -> Maybe Address -> Maybe TokenValue -> DisplayProfile -> Element Msg
viewMainBlock now saleStartTime maybeUserAddress maybeUserBalance dProfile =
    Element.column
        [ Element.centerX
        , Element.spacing <| responsiveVal dProfile 60 30
        , Element.Background.color <| Element.rgb 0.8 0.8 1
        , Element.Border.rounded 10
        , responsiveVal
            dProfile
            (Element.paddingXY 20 40)
            (Element.paddingEach
                { right = 5
                , left = 5
                , top = 20
                , bottom = 40
                }
            )
        , Element.width <|
            responsiveVal dProfile
                (Element.shrink |> Element.maximum 1200)
                Element.fill
        , Element.Border.glow
            (Element.rgba 1 1 1 0.3)
            5
        ]
        [ Element.column
            [ Element.spacing 25
            , Element.centerX
            ]
            [ case dProfile of
                Desktop ->
                    Element.el [ Element.Font.size 50 ] <| Element.text "The Permafrost Sale begins in"

                _ ->
                    Element.column
                        [ Element.spacing 3
                        , Element.centerX
                        ]
                        [ Element.el
                            [ Element.centerX
                            , Element.Font.size 30
                            ]
                          <|
                            Element.text "The Permafrost Sale"
                        , Element.el [ Element.centerX ] <| Element.text "begins in"
                        ]
            , countdownTimerEl now saleStartTime
            ]
        , Element.newTabLink
            [ Element.centerX
            , Element.Border.rounded 10
            , Element.padding <| responsiveVal dProfile 15 5
            , Element.Background.color EH.blue
            , Element.Border.shadow
                { offset = ( -3, 3 )
                , size = 0
                , blur = 3
                , color = Element.rgba 0 0 0 0.3
                }
            ]
            { url = "https://medium.com/@coinop.logan/permafrost-un-rug-pullable-liquidity-9aa98ecf33c8"
            , label =
                Element.el
                    [ Element.Font.color EH.white
                    , Element.Font.size <| responsiveVal dProfile 36 26
                    ]
                <|
                    Element.text "What's the Permafrost Sale?"
            }
        , embeddedYoutubeElOrMobileWarning dProfile
        , tokenOutputEl dProfile maybeUserAddress maybeUserBalance
        , paragraphs dProfile <|
            [ [ Element.text "This sale will accept "
              , emphasizedText "ETH/FRY Balancer Liquidity Tokens"
              , Element.text " in exchange for freshly minted "
              , link "FRY" "https://foundrydao.com/"
              , Element.text ", using the same sale mechanism as with the "
              , link "still-running original FRY sale" "https://sale.foundrydao.com/"
              , Element.text ". See the videos at that link for more information on how this \"bucket sale\" works."
              , Element.text " The main difference with this permafrost version is that it will accept deposits of "
              , emphasizedText "ETH/FRY liqudity"
              , Element.text " rather than DAI, and that it then "
              , emphasizedText "burns the liquidity tokens"
              , Element.text " instead of sending them to the Foundry Treasury."
              ]
            , [ Element.text "Burning these liquidity tokens results in "
              , emphasizedText "permanently locked or \"unrugpullable\" liquidity"
              , Element.text "."
              ]
            , [ Element.text "For now, you can get your liquidity tokens ready. If you're familiar with balancer, get liquidity tokens from "
              , link "this specific balancer pool" "https://pools.balancer.exchange/#/pool/0x5277a42ef95eca7637ffa9e69b65a12a089fe12b/"
              , Element.text ". For a bit more guidance, if you have both ETH and FRY, see "
              , link "this video" "https://www.youtube.com/watch?v=nR5Hv_-F49s&feature=youtu.be"
              , Element.text ". If you only have ETH, "
              , link "this video" "https://www.youtube.com/watch?v=APW_yTX6Pao&feature=youtu.be"
              , Element.text " demonstrates an alternate method, but this incurs an extra 10% fee."
              ]
            , [ Element.text "Return to this page to verify you have the right liquidity tokens."
              , responsiveVal dProfile
                    Element.none
                    (Element.el [ Element.Font.color EH.softRed ] <| Element.text " But again, note that this sale won't work on mobile. When the sale starts you'll need to use a bigger screen.")
              ]
            ]
        ]


embeddedYoutubeElOrMobileWarning : DisplayProfile -> Element Msg
embeddedYoutubeElOrMobileWarning dProfile =
    Element.el
        [ Element.centerX ]
    <|
        case dProfile of
            Desktop ->
                Element.html
                    (Embed.Youtube.fromString "APW_yTX6Pao"
                        |> Embed.Youtube.attributes
                            [ Embed.Youtube.Attributes.width 1024
                            , Embed.Youtube.Attributes.height 580
                            ]
                        |> Embed.Youtube.toHtml
                    )

            _ ->
                paragraphs dProfile
                    [ [ Element.el [ Element.Font.color EH.softRed ] <| Element.text "Note that the sale won't work on mobile. When the sale starts you'll need to use a bigger screen." ] ]


link : String -> String -> Element Msg
link label url =
    Element.newTabLink
        [ Element.Font.color EH.blue ]
        { url = url
        , label = Element.text label
        }


emphasizedText : String -> Element Msg
emphasizedText =
    Element.el [ Element.Font.bold ] << Element.text


paragraphs : DisplayProfile -> List (List (Element Msg)) -> Element Msg
paragraphs dProfile lists =
    Element.column
        [ Element.spacing 15
        , Element.width Element.fill
        , Element.Font.center
        , responsiveVal dProfile
            (Element.paddingXY 40 0)
            (Element.paddingXY 10 0)
        ]
        (List.map
            (Element.paragraph
                [ Element.Font.size 18
                ]
            )
            lists
        )


countdownTimerEl : Time.Posix -> Time.Posix -> Element Msg
countdownTimerEl now saleStartTime =
    let
        hri =
            TimeHelpers.toHumanReadableInterval
                (TimeHelpers.sub saleStartTime now)
    in
    Element.row
        [ Element.centerX
        , Element.spacing 10
        ]
        [ countdownCell hri.days "DAYS"
        , countdownCell hri.hours "HOURS"
        , countdownCell hri.min "MIN"
        , countdownCell hri.sec "SEC"
        ]


countdownCell : Int -> String -> Element Msg
countdownCell num label =
    Element.column
        [ Element.spacing 5
        , Element.width <| Element.px 70
        , Element.Background.color <| Element.rgb255 20 53 138
        , Element.padding 5
        , Element.Border.rounded 5
        , Element.Font.color EH.white
        , Element.Border.shadow
            { offset = ( -3, 3 )
            , size = 2
            , blur = 5
            , color = Element.rgba 0 0 0 0.3
            }
        ]
        [ Element.el
            [ Element.Font.size 50
            , Element.centerX
            ]
          <|
            Element.text <|
                String.fromInt num
        , Element.el
            [ Element.Font.size 16
            , Element.centerX
            , Element.Font.bold
            ]
          <|
            Element.text label
        ]


tokenOutputEl : DisplayProfile -> Maybe Address -> Maybe TokenValue -> Element Msg
tokenOutputEl dProfile maybeUserAddress maybeBalance =
    Element.column
        [ Element.centerX
        , Element.width Element.fill
        , Element.spacing 10
        , Element.padding 10
        , Element.Border.rounded 5
        , Element.Background.color <| Element.rgba 1 1 1 0.14
        , Element.Border.width 1
        , Element.Border.color <| Element.rgba 0 0 0 0.1
        , Element.Border.innerGlow
            (Element.rgba 0 0 0 0.1)
            3
        ]
    <|
        case maybeUserAddress of
            Just userAddress ->
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
                , Element.paragraph
                    [ Element.width Element.fill
                    , Element.Font.center
                    , Element.Font.size 16
                    ]
                    [ Element.text <|
                        "Your balance of the accepted ETHFRY Liquidity Tokens"
                    ]
                ]

            Nothing ->
                [ Element.paragraph
                    [ Element.width Element.fill
                    , Element.Font.center
                    , Element.Font.size 16
                    ]
                    [ Element.text "Connect your wallet to verify you have the right liquidity tokens." ]
                , connectToWeb3Button dProfile
                ]


connectToWeb3Button : DisplayProfile -> Element Msg
connectToWeb3Button dProfile =
    Element.el
        [ Element.centerX
        , Element.padding <| responsiveVal dProfile 17 10
        , Element.Border.rounded 4
        , Element.Font.size <| responsiveVal dProfile 20 16
        , Element.Font.semiBold
        , Element.Font.center
        , Element.Background.color EH.softRed
        , Element.Font.color EH.white
        , Element.pointer
        , Element.Events.onClick <| CmdUp CmdUp.Web3Connect
        ]
        (Element.text "Connect to Wallet")
