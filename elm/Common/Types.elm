module Common.Types exposing (..)

import Dict
import Eth.Net
import Eth.Types exposing (Address, HttpProvider)
import Json.Decode
import Json.Encode


type TestMode
    = None
    | TestMainnet
    | TestKovan
    | TestGanache


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


type SaleType
    = Standard
    | Advanced


type EnteringToken
    = DAI
    | ETH
