module View exposing (root)

import Home.View
import UserNotice as UN exposing (UserNotice)
import Browser
import BucketSale.View
import CommonTypes exposing (..)
import Element exposing (Attribute, Element)
import Element.Background
import Element.Border
import Element.Events
import Element.Font
import Helpers.Element as EH
import Images exposing (Image)
import Routing
import Types exposing (..)


root : Model -> Browser.Document Msg
root model =
    { title = "Foundry"
    , body =
        [ let
            ( pageEl, modalEls ) =
                pageElementAndModal model.dProfile model

            mainElementAttributes =
                [ Element.width Element.fill
                , Element.height Element.fill
                , Element.Events.onClick ClickHappened
                , Element.Font.family
                    [ Element.Font.typeface "Soleil"
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


pageElementAndModal : DisplayProfile -> Model -> ( Element Msg, List (Element Msg) )
pageElementAndModal dProfile model =
    let
        ( submodelEl, modalEls ) =
            submodelElementAndModal dProfile model

        maybeTestnetIndicator =
            if model.testMode then
                Element.el
                    [ Element.centerX
                    , Element.Font.size (24 |> changeForMobile 16 dProfile)
                    , Element.Font.bold
                    , Element.Font.italic
                    , Element.Font.color EH.softRed
                    ]
                    (Element.text "In Test (Kovan) mode")

            else
                Element.none
    in
    ( Element.column
        [ Element.behindContent <| headerBackground dProfile
        , Element.inFront <| headerContent dProfile model
        , Element.width Element.fill
        , Element.height Element.fill
        , Element.padding (30 |> changeForMobile 10 dProfile)
        , Element.spacing (20 |> changeForMobile 10 dProfile)
        ]
        [ Element.el
            [ Element.height (Element.px (60 |> changeForMobile 110 dProfile)) ]
            Element.none
        , maybeTestnetIndicator 
        , submodelEl
        ]
    , modalEls ++ userNoticeEls dProfile model.userNotices
    )


headerBackground : DisplayProfile -> Element Msg
headerBackground dProfile =
    let
        bottomBackgroundColor =
            Element.rgb255 10 33 108

        headerColor =
            Element.rgb255 7 27 92
    in
    Element.el
        [ Element.width Element.fill
        , Element.height <| Element.px 600
        , Element.Background.color bottomBackgroundColor
        , Element.inFront <|
            Element.el
                [ Element.width Element.fill
                , Element.height <| Element.px (80 |> changeForMobile 120 dProfile)
                , Element.Background.color headerColor
                ]
                Element.none
        ]
        Element.none


headerContent : DisplayProfile -> Model -> Element Msg
headerContent dProfile model =
    Element.row
        [ Element.width Element.fill
        , Element.spacing (30 |> changeForMobile 10 dProfile)
        , Element.paddingXY 30 17 |> changeForMobile (Element.padding 10) dProfile
        ]
        [ let
            smLinks =
                [ Element.el
                    [ Element.centerY
                    , Element.alignRight
                    ]
                  <|
                    headerExternalLink dProfile "Blog" "https://medium.com/daihard-buidlers"
                , Element.el
                    [ Element.centerY
                    , Element.alignRight
                    ]
                  <|
                    headerExternalLink dProfile "Reddit" "https://reddit.com/r/DAIHard"
                , Element.el
                    [ Element.centerY
                    , Element.alignRight
                    ]
                  <|
                    headerExternalLink dProfile "Telegram" "https://t.me/daihardexchange_group"
                ]
          in
          case dProfile of
            Desktop ->
                Element.column
                    [ Element.spacing 5
                    , Element.alignRight
                    , Element.alignTop
                    ]
                    [ Element.el [ Element.alignRight ] <| logoElement dProfile
                    , Element.row
                        [ Element.spacing 10
                        ]
                        smLinks
                    ]

            Mobile ->
                Element.column
                    [ Element.spacing 10
                    , Element.alignTop
                    , Element.alignRight
                    ]
                    ([ logoElement dProfile ] ++ smLinks)
        ]


type HeaderLinkStyle
    = Normal
    | Active
    | Important


headerLinkBaseStyles : DisplayProfile -> List (Attribute Msg)
headerLinkBaseStyles dProfile =
    (case dProfile of
        Desktop ->
            [ Element.paddingXY 23 12
            , Element.Font.size 21
            , Element.Font.semiBold
            , Element.spacing 13
            ]

        Mobile ->
            [ Element.paddingXY 10 5
            , Element.Font.size 16
            , Element.spacing 6
            ]
    )
        ++ [ Element.Font.color EH.white
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
                , Element.height <| Element.px (26 |> changeForMobile 14 dProfile)
                ]
            <|
                Element.text title
        }


headerLink : DisplayProfile -> Maybe Image -> String -> Msg -> HeaderLinkStyle -> Element Msg
headerLink dProfile maybeIcon title onClick style =
    let
        height =
            26 |> changeForMobile 18 dProfile

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
        (headerLinkBaseStyles dProfile
            ++ [ Element.Events.onClick onClick ]
            ++ extraStyles
        )
        [ Maybe.map
            (Images.toElement
                [ Element.height <| Element.px height ]
            )
            maybeIcon
            |> Maybe.withDefault Element.none
        , Element.el
            [ Element.centerY
            , Element.height <| Element.px height
            ]
          <|
            Element.text title
        ]


logoElement : DisplayProfile -> Element Msg
logoElement dProfile =
    Element.el
        [ Element.Font.size (29 |> changeForMobile 20 dProfile)
        , Element.Font.color EH.white
        , Element.Font.bold
        , Element.centerX
        , Element.pointer
        , Element.Events.onClick <| GotoRoute Routing.Sale
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


submodelElementAndModal : DisplayProfile -> Model -> ( Element Msg, List (Element Msg) )
submodelElementAndModal dProfile model =
    let
        ( submodelEl, modalEls ) =
            case model.submodel of
                Home ->
                    Home.View.root

                BucketSaleModel bucketSaleModel ->
                    BucketSale.View.root bucketSaleModel
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
            [ Element.moveLeft (20 |> changeForMobile 5 dProfile)
            , Element.moveUp (20 |> changeForMobile 5 dProfile)
            , Element.spacing (10 |> changeForMobile 5 dProfile)
            , Element.alignRight
            , Element.alignBottom
            , Element.width <| Element.px (300 |> changeForMobile 150 dProfile)
            , Element.Font.size (15 |> changeForMobile 10 dProfile)
            ]
            (notices
                |> List.indexedMap (\id notice -> ( id, notice ))
                |> List.filter (\( _, notice ) -> notice.align == UN.BottomRight)
                |> List.map (userNotice dProfile)
            )
        , Element.column
            [ Element.moveRight (20 |> changeForMobile 5 dProfile)
            , Element.moveDown 100
            , Element.spacing (10 |> changeForMobile 5 dProfile)
            , Element.alignLeft
            , Element.alignTop
            , Element.width <| Element.px (300 |> changeForMobile 150 dProfile)
            , Element.Font.size (15 |> changeForMobile 10 dProfile)
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
        , Element.Border.rounded (10 |> changeForMobile 5 dProfile)
        , Element.padding (8 |> changeForMobile 3 dProfile)
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