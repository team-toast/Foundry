module View exposing (root)

import Browser
import BucketSale.View
import CommonTypes exposing (..)
import Config
import Element exposing (Attribute, Element)
import Element.Background
import Element.Border
import Element.Events
import Element.Font
import Helpers.Element as EH
import Images exposing (Image)
import Routing
import Time
import Types exposing (..)
import UserNotice as UN exposing (UserNotice)
import Wallet


root : Model -> Browser.Document Msg
root model =
    { title = Config.appTitle
    , body =
        [ let
            ( pageEl, modalEls ) =
                pageElementAndModal model

            mainElementAttributes =
                [ Element.width Element.fill
                , Element.height Element.fill
                , Element.Events.onClick ClickHappened
                , Element.Font.family
                    [ Element.Font.typeface "DM Sans"
                    , Element.Font.sansSerif
                    ]
                ]
                    ++ List.map Element.inFront modalEls
          in
          Element.layoutWith
            { options =
                [ Element.focusStyle
                    { borderColor = Nothing
                    , backgroundColor = Nothing
                    , shadow = Nothing
                    }
                ]
            }
            mainElementAttributes
            pageEl
        ]
    }


pageElementAndModal : Model -> ( Element Msg, List (Element Msg) )
pageElementAndModal model =
    -- if model.dProfile /= Desktop && model.displayMobileWarning then
    --     ( Element.column
    --         [ Element.width Element.fill
    --         , Element.height Element.fill
    --         , Element.Background.color <| Element.rgb255 20 53 138
    --         , Element.spacing 30
    --         , Element.paddingXY 10 30
    --         , Element.Font.size 22
    --         , Element.Font.color EH.white
    --         ]
    --         [ Element.paragraph [ Element.Font.center ]
    --             [ Element.text "This interface is not designed for screens this small. To participate in this sale, visit on a larger screen. Alternatively, some mobile browsers have a \"desktop mode\" that might help." ]
    --         , Element.paragraph [ Element.Font.center ]
    --             [ Element.text "If you're just looking for info on Foundry, FRY, or the sale, check out "
    --             , Element.newTabLink
    --                 [ Element.Font.color EH.lightBlue
    --                 ]
    --                 { url = "https://foundrydao.com"
    --                 , label = Element.text "foundrydao.com"
    --                 }
    --             , Element.text "."
    --             ]
    --         ]
    --     , []
    --     )
    -- else
    let
        ( submodelEl, modalEls ) =
            submodelElementAndModal model

        maybeTestnetIndicator =
            Element.el
                [ Element.centerX
                , Element.Font.size <|
                    responsiveVal model.dProfile 24 10
                , Element.Font.bold
                , Element.Font.italic
                , Element.Font.color EH.softRed
                ]
            <|
                case model.testMode of
                    None ->
                        Element.none

                    TestMainnet ->
                        Element.text "In Test (Mainnet) mode"

                    TestKovan ->
                        Element.text "In Test (Kovan) mode"

                    TestGanache ->
                        Element.text "In Test (Local) mode"
    in
    ( Element.column
        [ Element.width Element.fill
        , Element.height Element.fill
        , Element.spacing 20
        , Element.behindContent <|
            headerBackground model.dProfile
        ]
        [ header model.dProfile
        , maybeTestnetIndicator
        , Element.el
            [ Element.width Element.fill
            , Element.paddingXY (responsiveVal model.dProfile 20 10) 0
            ]
            submodelEl
        ]
    , modalEls
        ++ userNoticeEls
            model.dProfile
            model.userNotices
    )


headerBackground : DisplayProfile -> Element Msg
headerBackground dProfile =
    Element.el
        [ Element.width Element.fill
        , Element.height
            (case dProfile of
                Desktop ->
                    Element.px 600

                SmallDesktop ->
                    Element.fill
            )
        , Element.Background.color <| Element.rgb255 20 53 138
        ]
        Element.none


header : DisplayProfile -> Element Msg
header dProfile =
    case dProfile of
        Desktop ->
            Element.row
                [ Element.height <|
                    Element.px 100
                , Element.width Element.fill
                , Element.Background.color <|
                    Element.rgb255 10 33 108
                ]
                [ Element.el
                    [ Element.alignLeft
                    , Element.centerY
                    ]
                    (brandAndLogo dProfile)
                , Element.el
                    [ Element.alignRight
                    , Element.centerY
                    ]
                    (smLinks dProfile)
                ]

        SmallDesktop ->
            Element.column
                [ Element.width Element.fill ]
                [ Element.el
                    [ Element.width Element.fill
                    , Element.centerX
                    , Element.Background.color <|
                        Element.rgb255 10 33 108
                    ]
                    (brandAndLogo dProfile)
                , smLinks dProfile
                ]


brandAndLogo : DisplayProfile -> Element Msg
brandAndLogo dProfile =
    case dProfile of
        Desktop ->
            Element.row
                [ Element.height Element.fill
                , Element.padding 20
                , Element.spacing 10
                ]
                [ Images.toElement
                    [ Element.centerY ]
                    Images.exitingTokenIcon
                , Element.column
                    [ Element.spacing 5 ]
                    [ Element.el
                        [ Element.Font.color EH.white
                        , Element.Font.size 35
                        , Element.Font.bold
                        , Element.centerY
                        ]
                      <|
                        Element.text "Foundry Sale"
                    , Element.newTabLink
                        [ Element.alignLeft
                        , Element.Background.color EH.lightBlue
                        , Element.paddingXY 10 3
                        , Element.Border.rounded 4
                        , Element.Font.color EH.white
                        , Element.Font.size 18
                        ]
                        { url = "https://foundrydao.com"
                        , label =
                            Element.text "What is Foundry?"
                        }
                    ]
                ]

        SmallDesktop ->
            Element.row
                [ Element.height Element.fill
                , Element.centerX
                , Element.padding 10
                , Element.spacing 5
                ]
                [ Images.toElement
                    [ Element.centerY
                    , Element.width <|
                        Element.px 25
                    , Element.height <|
                        Element.px 25
                    ]
                    Images.exitingTokenIcon
                , Element.el
                    [ Element.Font.color EH.white
                    , Element.Font.size 16
                    , Element.Font.bold
                    , Element.centerY
                    ]
                  <|
                    Element.text "Foundry Sale"
                , Element.newTabLink
                    [ Element.Background.color EH.lightBlue
                    , Element.paddingXY 5 2
                    , Element.Border.rounded 4
                    , Element.Font.color EH.white
                    , Element.Font.size 10
                    ]
                    { url = "https://foundrydao.com"
                    , label =
                        Element.text "What is Foundry?"
                    }
                ]


smLinks : DisplayProfile -> Element Msg
smLinks dProfile =
    [ ( Images.twitter, "https://twitter.com/FoundryDAO" )
    , ( Images.github, "https://github.com/burnable-tech/foundry/" )
    , ( Images.telegram, "https://t.me/FoundryCommunity" )
    , ( Images.medium, "https://medium.com/daihard-buidlers" )
    , ( Images.reddit, "https://www.reddit.com/r/FoundryDAO/" )
    , ( Images.forum, "https://forum.foundrydao.com/" )
    ]
        |> List.map
            (\( image, url ) ->
                Element.newTabLink
                    []
                    { url = url
                    , label =
                        Images.toElement
                            [ Element.height <|
                                Element.px <|
                                    responsiveVal dProfile 40 20
                            ]
                            image
                    }
            )
        |> Element.row
            ([ Element.padding <|
                responsiveVal dProfile 10 5
             , Element.spacing <|
                responsiveVal dProfile 20 10
             ]
                ++ (case dProfile of
                        Desktop ->
                            []

                        SmallDesktop ->
                            [ Element.centerX
                            ]
                   )
            )


type HeaderLinkStyle
    = Normal
    | Active
    | Important


headerLinkBaseStyles : List (Attribute Msg)
headerLinkBaseStyles =
    [ Element.paddingXY 23 12
    , Element.Font.size 21
    , Element.Font.semiBold
    , Element.spacing 13
    , Element.Font.color EH.white
    , Element.pointer
    , EH.noSelectText
    ]


headerExternalLink : DisplayProfile -> String -> String -> Element Msg
headerExternalLink dProfile title url =
    Element.link
        [ Element.Font.size 16
        , Element.Font.semiBold
        , Element.Font.color EH.white
        , Element.pointer
        , EH.noSelectText
        ]
        { url = url
        , label =
            Element.el
                [ Element.centerY
                , Element.height <| Element.px 26
                ]
            <|
                Element.text title
        }


headerLink : DisplayProfile -> Maybe Image -> String -> Msg -> HeaderLinkStyle -> Element Msg
headerLink dProfile maybeIcon title onClick style =
    let
        extraStyles =
            case style of
                Normal ->
                    []

                Active ->
                    [ Element.Border.rounded 4
                    , Element.Background.color <| Element.rgb255 2 172 214
                    ]

                Important ->
                    [ Element.Border.rounded 4
                    , Element.Background.color EH.softRed
                    ]
    in
    Element.row
        (headerLinkBaseStyles
            ++ [ Element.Events.onClick onClick ]
            ++ extraStyles
        )
        [ Maybe.map
            (Images.toElement
                [ Element.height <| Element.px 26 ]
            )
            maybeIcon
            |> Maybe.withDefault Element.none
        , Element.el
            [ Element.centerY
            , Element.height <| Element.px 26
            ]
          <|
            Element.text title
        ]


logoElement : DisplayProfile -> Element Msg
logoElement dProfile =
    Element.el
        [ Element.Font.size 29
        , Element.Font.color EH.white
        , Element.Font.bold
        , Element.centerX
        , EH.noSelectText
        ]
        (Element.el [ Element.Font.color EH.softRed ] <| Element.text "Foundry")


headerMenuAttributes : List (Attribute Msg)
headerMenuAttributes =
    [ Element.Font.size 19
    , Element.Font.color EH.white
    , Element.Font.semiBold
    , Element.padding 20
    , Element.pointer
    ]


submodelElementAndModal : Model -> ( Element Msg, List (Element Msg) )
submodelElementAndModal model =
    let
        ( submodelEl, modalEls ) =
            case model.submodel of
                LoadingSaleModel bucketSaleLoadingModel ->
                    ( viewBucketSaleLoading bucketSaleLoadingModel model.wallet model.now model.dProfile
                    , []
                    )

                BucketSaleModel bucketSaleModel ->
                    BucketSale.View.root bucketSaleModel model.maybeReferrer model.dProfile
                        |> Tuple.mapBoth
                            (Element.map BucketSaleMsg)
                            (List.map (Element.map BucketSaleMsg))
    in
    ( Element.el
        [ Element.width Element.fill
        , Element.height Element.fill
        , Element.Border.rounded 10
        ]
        submodelEl
    , modalEls
    )


userNoticeEls : DisplayProfile -> List (UserNotice Msg) -> List (Element Msg)
userNoticeEls dProfile notices =
    if notices == [] then
        []

    else
        [ Element.column
            [ Element.moveLeft 20
            , Element.moveUp 70
            , Element.spacing 10
            , Element.alignRight
            , Element.alignBottom
            , Element.width <| Element.px 300
            , Element.Font.size 15
            ]
            (notices
                |> List.indexedMap (\id notice -> ( id, notice ))
                |> List.filter (\( _, notice ) -> notice.align == UN.BottomRight)
                |> List.map (userNotice dProfile)
            )
        , Element.column
            [ Element.moveRight 20
            , Element.moveDown 100
            , Element.spacing 10
            , Element.alignLeft
            , Element.alignTop
            , Element.width <| Element.px 300
            , Element.Font.size 15
            ]
            (notices
                |> List.indexedMap (\id notice -> ( id, notice ))
                |> List.filter (\( _, notice ) -> notice.align == UN.TopLeft)
                |> List.map (userNotice dProfile)
            )
        ]


userNotice : DisplayProfile -> ( Int, UserNotice Msg ) -> Element Msg
userNotice dProfile ( id, notice ) =
    let
        color =
            case notice.noticeType of
                UN.Update ->
                    Element.rgb255 100 200 255

                UN.Caution ->
                    Element.rgb255 255 188 0

                UN.Error ->
                    Element.rgb255 255 70 70

                UN.ShouldBeImpossible ->
                    Element.rgb255 200 200 200

        textColor =
            case notice.noticeType of
                UN.Error ->
                    Element.rgb 1 1 1

                _ ->
                    Element.rgb 0 0 0

        closeElement =
            Element.el
                [ Element.alignRight
                , Element.alignTop
                , Element.moveUp 5
                , Element.moveRight 5
                ]
                (EH.closeButton True (DismissNotice id))
    in
    Element.el
        [ Element.Background.color color
        , Element.Border.rounded 10
        , Element.padding 8
        , Element.width Element.fill
        , Element.Border.width 1
        , Element.Border.color <| Element.rgba 0 0 0 0.15
        , EH.subtleShadow
        , EH.onClickNoPropagation NoOp
        ]
        (notice.mainParagraphs
            |> List.indexedMap
                (\pNum paragraphLines ->
                    Element.paragraph
                        [ Element.width Element.fill
                        , Element.Font.color textColor
                        , Element.spacing 1
                        ]
                        (if pNum == 0 then
                            closeElement :: paragraphLines

                         else
                            paragraphLines
                        )
                )
            |> Element.column
                [ Element.spacing 4
                , Element.width Element.fill
                ]
        )


viewBucketSaleLoading : BucketSaleLoadingModel -> Wallet.State -> Time.Posix -> DisplayProfile -> Element Msg
viewBucketSaleLoading bucketSaleLoadingModel wallet now dProfile =
    case bucketSaleLoadingModel.loadingState of
        Loading ->
            bigCenteredText "Fetching Sale Contract State..." dProfile

        Error SaleNotDeployed ->
            bigCenteredText "The sale contract doesn't seem to be deployed yet." dProfile

        Error (SaleNotStarted startTime) ->
            bigCenteredText "The sale hasn't started yet!" dProfile



-- ViewCountdownPage.view
--     now
--     startTime
--     (Wallet.userInfo wallet |> Maybe.map .address)
--     bucketSaleLoadingModel.userBalance


bigCenteredText : String -> DisplayProfile -> Element Msg
bigCenteredText text dProfile =
    Element.paragraph
        [ Element.centerX
        , Element.paddingXY
            (responsiveVal dProfile 50 25)
            (responsiveVal dProfile 20 10)
        , Element.Font.size <|
            responsiveVal dProfile 30 12
        , Element.Font.color EH.white
        , Element.Font.center
        ]
        [ Element.text text ]
