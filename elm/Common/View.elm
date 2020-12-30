module Common.View exposing (..)

import Element exposing (Element)
import Element.Events
import Images

closeButton : Bool -> msg -> Element msg
closeButton isBlack msg =
    Element.el
        [ Element.padding 10
        , Element.Events.onClick msg
        , Element.pointer
        ]
        (Images.toElement [ Element.width <| Element.px 22 ]
            (if isBlack then
                Images.closeIconBlack

             else
                Images.closeIconWhite
            )
        )