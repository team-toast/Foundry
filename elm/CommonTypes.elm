module CommonTypes exposing (..)

import Dict
import Eth.Net
import Eth.Types exposing (Address)
import Json.Decode
import Json.Encode


type TestMode
    = None
    | TestMainnet
    | TestKovan
    | TestGanache


type DisplayProfile
    = Desktop
    | SmallDesktop


type alias GTagData =
    { event : String
    , category : String
    , label : String
    , value : Int
    }


type alias UserInfo =
    { network : Eth.Net.NetworkId
    , address : Address
    }


type SaleTypeUI
    = SingleBucket
    | MultiBucket


type EnteringToken
    = DAI
    | ETH


screenWidthToDisplayProfile : Int -> DisplayProfile
screenWidthToDisplayProfile width =
    if width >= 1280 then
        Desktop

    else
        SmallDesktop


responsiveVal : DisplayProfile -> a -> a -> a
responsiveVal dProfile val1 val2 =
    case dProfile of
        Desktop ->
            val1

        SmallDesktop ->
            val2
