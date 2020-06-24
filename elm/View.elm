module View exposing (root)

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
import UserNotice as UN exposing (UserNotice)


root : Model -> Browser.Document Msg
root model =
    { title = "Foundry Sale"
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
    if model.dProfile /= Desktop && model.displayMobileWarning then
        ( Element.column
            [ Element.width Element.fill
            , Element.height Element.fill
            , Element.Background.color <| Element.rgb255 20 53 138
            , Element.spacing 30
            , Element.paddingXY 10 30
            , Element.Font.size 22
            , Element.Font.color EH.white
            ]
            [ Element.paragraph [ Element.Font.center ]
                [ Element.text "This interface is not designed for screens this small. To participate in this sale, visit on a larger screen. Alternatively, some mobile browsers have a \"desktop mode\" that might help." ]
            , Element.paragraph [ Element.Font.center ]
                [ Element.text "If you're just looking for info on Foundry, FRY, or the sale, check out "
                , Element.newTabLink
                    [ Element.Font.color EH.lightBlue
                    ]
                    { url = "https://foundrydao.com"
                    , label = Element.text "foundrydao.com"
                    }
                , Element.text "."
                ]
            ]
        , []
        )

    else
        let
            ( submodelEl, modalEls ) =
                submodelElementAndModal model

            maybeTestnetIndicator =
                Element.el
                    [ Element.centerX
                    , Element.Font.size (24 |> changeForMobile 16 model.dProfile)
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
            , Element.spacing (20 |> changeForMobile 10 model.dProfile)
            , Element.behindContent <| headerBackground model.dProfile
            ]
            [ header model.dProfile
            , maybeTestnetIndicator
            , Element.el
                [ Element.width Element.fill
                , Element.paddingXY 20 0
                ]
                submodelEl
            ]
        , modalEls ++ userNoticeEls model.dProfile model.userNotices
        )


headerBackground : DisplayProfile -> Element Msg
headerBackground dProfile =
    Element.el
        [ Element.width Element.fill
        , Element.height <| Element.px 600
        , Element.Background.color <| Element.rgb255 20 53 138
        ]
        Element.none


header : DisplayProfile -> Element Msg
header dProfile =
    Element.row
        [ Element.height <| Element.px 100
        , Element.width Element.fill
        , Element.Background.color <| Element.rgb255 10 33 108
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


brandAndLogo : DisplayProfile -> Element Msg
brandAndLogo dProfile =
    Element.row
        [ Element.height Element.fill
        , Element.padding (20 |> changeForMobile 10 dProfile)
        , Element.spacing 10
        ]
        [ Images.toElement
            [ Element.centerY ]
            Images.fryIcon
        , Element.column
            [ Element.spacing 5 ]
            [ Element.el
                [ Element.Font.color EH.white
                , Element.Font.size 35
                , Element.Font.bold
                , Element.centerY
                ]
              <|
                Element.text "Foundry"
            , Element.newTabLink
                [ Element.centerX
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


smLinks : DisplayProfile -> Element Msg
smLinks dProfile =
    [ ( Images.twitter, "https://twitter.com/FoundryDAO" )
    , ( Images.github, "https://github.com/burnable-tech/foundry/" )
    ]
        |> List.map
            (\( image, url ) ->
                Element.newTabLink
                    []
                    { url = url
                    , label =
                        Images.toElement
                            [ Element.height <| Element.px 40 ]
                            image
                    }
            )
        |> Element.row
            [ Element.padding 10
            , Element.spacing 20
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


submodelElementAndModal : Model -> ( Element Msg, List (Element Msg) )
submodelElementAndModal model =
    let
        ( submodelEl, modalEls ) =
            case model.submodel of
                NullSubmodel ->
                    ( Element.none
                    , []
                    )

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
