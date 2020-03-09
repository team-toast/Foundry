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
        { src = "img/dai-symbol.png"
        , description = "DAI"
        }


downArrow : Image
downArrow =
    JustImage
        { src = "img/arrow-down.svg"
        , description = "down"
        }


upArrow : Image
upArrow =
    JustImage
        { src = "img/arrow-up.svg"
        , description = "up"
        }


qmarkCircle : Image
qmarkCircle =
    JustImage
        { src = "img/qmark-circle.svg"
        , description = ""
        }





loadingArrows : Image
loadingArrows =
    JustImage
        { src = "img/loading-arrows.svg"
        , description = "waiting"
        }


closeIconBlack : Image
closeIconBlack =
    JustImage
        { src = "img/remove-circle-black.svg"
        , description = "close"
        }


closeIconWhite : Image
closeIconWhite =
    JustImage
        { src = "img/remove-circle-white.svg"
        , description = "close"
        }


flame : Image
flame =
    JustImage
        { src = "img/flame.png"
        , description = "flame"
        }



navigateLeft : Image
navigateLeft =
    JustImage
        { src = "img/keyboard-arrow-left.svg"
        , description = "left"
        }


navigateRight : Image
navigateRight =
    JustImage
        { src = "img/keyboard-arrow-right.svg"
        , description = "right"
        }


searchIcon : Image
searchIcon =
    JustImage
        { src = "img/search.svg"
        , description = "search"
        }

foundrySchematic : Image
foundrySchematic =
    JustImage
        {src = "img/foundry-schematic.png"
        , description = "foundry schematic"
        }