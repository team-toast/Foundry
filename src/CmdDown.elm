module CmdDown exposing (CmdDown(..))

import CommonTypes exposing (..)
import Wallet
import Eth.Types exposing (Address)

type CmdDown
    = UpdateWallet Wallet.State
    | UpdateReferral Address
    | CloseAnyDropdownsOrModals
