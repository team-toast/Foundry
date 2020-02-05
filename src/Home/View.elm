module Home.View exposing (root)

import Element exposing (Element)
import Element.Font
import Helpers.Element as EH
import Types exposing (..)


root : ( Element Msg, List (Element Msg) )
root =
    ( Element.el
        [ Element.Font.size 30
        , Element.centerX
        , Element.padding 20
        , Element.Font.color EH.white
        ]
        (Element.text "Foundry Home page coming soon...")
    , []
    )
