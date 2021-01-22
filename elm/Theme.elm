module Theme exposing (..)

import Element exposing (Attribute, Element)
import Element.Background
import Element.Border
import Element.Font
import ElementHelpers as EH exposing (DisplayProfile(..))


red =
    Element.rgb255 226 1 79


softRed =
    Element.rgb255 255 0 110


lightRed =
    Element.rgb 1 0.8 0.8


green =
    Element.rgb255 51 183 2


blue =
    Element.rgb 0 0 1


lightBlue =
    Element.rgb255 25 169 214


yellow =
    Element.rgb 1 1 0


daiYellow =
    yellow


dollarGreen =
    green


darkYellow =
    Element.rgb 0.6 0.6 0


lightGray =
    Element.rgb255 233 237 242


placeholderTextColor =
    Element.rgb255 213 217 222


mediumGray =
    Element.rgb255 200 205 210


darkGray =
    Element.rgb255 150 150 150


activePhaseBackgroundColor =
    Element.rgb255 9 32 107


permanentTextColor =
    Element.rgba255 1 31 52 0.8


submodelBackgroundColor =
    Element.rgb 0.95 0.98 1


pageBackgroundColor =
    Element.rgb255 242 243 247


disabledTextColor =
    Element.rgba255 1 31 52 0.13


currencyLabelColor =
    Element.rgb255 109 127 138


releasedIconColor =
    Element.rgb255 0 255 0


abortedIconColor =
    Element.rgb255 250 165 22


burnedIconColor =
    Element.rgb255 255 0 0


blueButton : DisplayProfile -> List (Attribute msg) -> List String -> EH.ButtonAction msg -> Element msg
blueButton dProfile attributes text action =
    EH.button dProfile
        attributes
        ( Element.rgba 0 0 1 1
        , Element.rgba 0 0 1 0.8
        , Element.rgba 0 0 1 0.6
        )
        EH.white
        text
        action


lightBlueButton : DisplayProfile -> List (Attribute msg) -> List String -> EH.ButtonAction msg -> Element msg
lightBlueButton dProfile attributes text action =
    let
        color =
            lightBlue
    in
    EH.button dProfile
        attributes
        ( color
        , color |> EH.withAlpha 0.8
        , color |> EH.withAlpha 0.6
        )
        EH.white
        text
        action


inverseBlueButton : DisplayProfile -> List (Attribute msg) -> List String -> EH.ButtonAction msg -> Element msg
inverseBlueButton dProfile attributes text action =
    EH.button dProfile
        attributes
        ( Element.rgba 0 0 1 0.05
        , Element.rgba 0 0 1 0.1
        , Element.rgba 0 0 1 0.2
        )
        blue
        text
        action


redButton : DisplayProfile -> List (Attribute msg) -> List String -> EH.ButtonAction msg -> Element msg
redButton dProfile attributes text action =
    EH.button dProfile
        attributes
        ( Element.rgba 1 0 0 1
        , Element.rgba 1 0 0 0.8
        , Element.rgba 1 0 0 0.6
        )
        EH.white
        text
        action


greenButton : DisplayProfile -> List (Attribute msg) -> List String -> EH.ButtonAction msg -> Element msg
greenButton dProfile attributes text action =
    EH.button dProfile
        attributes
        ( Element.rgba 0 1 0 1
        , Element.rgba 0 1 0 0.8
        , Element.rgba 0 1 0 0.6
        )
        EH.white
        text
        action


commonButtonAttributes : DisplayProfile -> List (Attribute msg)
commonButtonAttributes dProfile =
    [ Element.Border.rounded 4
    , EH.responsiveVal dProfile
        (Element.paddingXY 25 17)
        (Element.paddingXY 10 5)
    , Element.Font.size
        (EH.responsiveVal dProfile 18 10)
    , Element.Font.semiBold
    , Element.Background.color lightGray
    , Element.Font.center
    , EH.noSelectText
    ]


disabledButton : DisplayProfile -> List (Attribute msg) -> String -> Maybe String -> Element msg
disabledButton dProfile attributes text maybeTipText =
    Element.el
        (attributes
            ++ commonButtonAttributes dProfile
            ++ [ Element.above <|
                    maybeErrorElement
                        [ Element.moveUp 5 ]
                        maybeTipText
               ]
        )
        (Element.text text)


disabledSuccessButton : DisplayProfile -> List (Attribute msg) -> String -> Maybe String -> Element msg
disabledSuccessButton dProfile attributes text maybeTipText =
    Element.el
        (attributes
            ++ commonButtonAttributes dProfile
            ++ [ Element.above <|
                    maybeErrorElement
                        [ Element.moveUp 5 ]
                        maybeTipText
               ]
        )
        (Element.text text)


maybeErrorElement : List (Attribute msg) -> Maybe String -> Element msg
maybeErrorElement attributes maybeError =
    case maybeError of
        Nothing ->
            Element.none

        Just errorString ->
            Element.el
                ([ Element.Border.rounded 5
                 , Element.Border.color softRed
                 , Element.Border.width 1
                 , Element.Background.color <| Element.rgb 1 0.4 0.4
                 , Element.padding 5
                 , Element.centerX
                 , Element.centerY
                 , Element.width (Element.shrink |> Element.maximum 200)
                 , Element.Font.size 14
                 ]
                    ++ attributes
                )
                (Element.paragraph
                    []
                    [ Element.text errorString ]
                )
