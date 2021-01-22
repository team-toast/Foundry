module CmdDown exposing (CmdDown(..))

import Common.Types exposing (..)
import Wallet
import Eth.Types exposing (Address)

type CmdDown
    = UpdateWallet Wallet.State
    | CloseAnyDropdownsOrModals
