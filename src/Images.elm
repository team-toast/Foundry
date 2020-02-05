module Images exposing (..)

import Element exposing (Attribute, Element)
import Time


type Image
    = None
    | JustImage
        { src : String
        , description : String
        }


toElement : List (Attribute msg) -> Image -> Element msg
toElement attributes image_ =
    case image_ of
        None ->
            Element.el attributes Element.none

        JustImage img ->
            Element.image attributes img


none =
    None


image =
    JustImage

daiSymbol : Image
daiSymbol =
    JustImage
        { src = "/static/img/dai-symbol.png"
        , description = "DAI"
        }


downArrow : Image
downArrow =
    JustImage
        { src = "/static/img/arrow-down.svg"
        , description = "down"
        }


upArrow : Image
upArrow =
    JustImage
        { src = "/static/img/arrow-up.svg"
        , description = "up"
        }


qmarkCircle : Image
qmarkCircle =
    JustImage
        { src = "/static/img/qmark-circle.svg"
        , description = ""
        }





loadingArrows : Image
loadingArrows =
    JustImage
        { src = "/static/img/loading-arrows.svg"
        , description = "waiting"
        }


closeIconBlack : Image
closeIconBlack =
    JustImage
        { src = "/static/img/remove-circle-black.svg"
        , description = "close"
        }


closeIconWhite : Image
closeIconWhite =
    JustImage
        { src = "/static/img/remove-circle-white.svg"
        , description = "close"
        }


flame : Image
flame =
    JustImage
        { src = "/static/img/flame.png"
        , description = "flame"
        }



navigateLeft : Image
navigateLeft =
    JustImage
        { src = "/static/img/keyboard-arrow-left.svg"
        , description = "left"
        }


navigateRight : Image
navigateRight =
    JustImage
        { src = "/static/img/keyboard-arrow-right.svg"
        , description = "right"
        }


searchIcon : Image
searchIcon =
    JustImage
        { src = "/static/img/search.svg"
        , description = "search"
        }