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


enteringTokenSymbol : Image
enteringTokenSymbol =
    daiSymbol


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


exitingTokenIcon : Image
exitingTokenIcon =
    JustImage
        { src = "img/fry-icon.svg"
        , description = "Foundry"
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
        { src = "img/foundry-schematic.png"
        , description = "foundry schematic"
        }


twitter : Image
twitter =
    JustImage
        { src = "img/social-media/twitter.svg"
        , description = "twitter"
        }


github : Image
github =
    JustImage
        { src = "img/social-media/github.svg"
        , description = "github"
        }


telegram : Image
telegram =
    JustImage
        { src = "img/social-media/telegram.svg"
        , description = "telegram"
        }


keybase : Image
keybase =
    JustImage
        { src = "img/social-media/keybase.svg"
        , description = "keybase"
        }


checkmark : Image
checkmark =
    JustImage
        { src = "img/check.svg"
        , description = "checked"
        }
