module Contracts.Wrappers exposing (..)

import BigInt exposing (BigInt)
import CommonTypes exposing (..)
import Config
import Contracts.Generated.ERC20Token as TokenContract
import Eth
import Eth.Decode
import Eth.Sentry.Event as EventSentry exposing (EventSentry)
import Eth.Types exposing (Address, Call)
import Eth.Utils
import Helpers.Eth as EthHelpers
import Helpers.Time as TimeHelpers
import Http
import Json.Decode
import Json.Encode
import Task
import Time
import TokenValue exposing (TokenValue)


getAllowanceCmd : TestMode -> Address -> Address -> (Result Http.Error BigInt -> msg) -> Cmd msg
getAllowanceCmd testMode owner spender msgConstructor =
    Eth.call
        (EthHelpers.appHttpProvider testMode)
        (TokenContract.allowance
            (Config.enteringTokenAddress testMode)
            owner
            spender
        )
        |> Task.attempt msgConstructor
