module SelectHttpProvider exposing (..)

import Common.Types exposing (..)
import Config
import Eth.Net
import Eth.Types exposing (HttpProvider)


appHttpProvider : TestMode -> HttpProvider
appHttpProvider testMode =
    case testMode of
        None ->
            Config.mainnetHttpProviderUrl

        TestMainnet ->
            Config.mainnetHttpProviderUrl

        TestKovan ->
            Config.kovanHttpProviderUrl

        TestGanache ->
            Config.ganacheProviderUrl


networkToHttpProvider : Eth.Net.NetworkId -> Maybe HttpProvider
networkToHttpProvider networkId =
    case networkId of
        Eth.Net.Mainnet ->
            Just Config.mainnetHttpProviderUrl

        Eth.Net.Kovan ->
            Just Config.kovanHttpProviderUrl

        Eth.Net.Private 123456 ->
            Just Config.ganacheProviderUrl

        _ ->
            Nothing
