module Config exposing (..)

import BigInt exposing (BigInt)
import CommonTypes exposing (..)
import Eth.Types exposing (Address)
import Eth.Utils
import Time
import TokenValue exposing (TokenValue)


mainnetHttpProviderUrl : String
mainnetHttpProviderUrl =
    "https://mainnet.infura.io/v3/e3eef0e2435349bf9164e6f465bd7cf9"


kovanHttpProviderUrl : String
kovanHttpProviderUrl =
    "https://kovan.infura.io/v3/e3eef0e2435349bf9164e6f465bd7cf9"


ganacheProviderUrl : String
ganacheProviderUrl =
    "http://localhost:8545"


daiContractAddress : TestMode -> Address
daiContractAddress testMode =
    case testMode of
        None ->
            Debug.todo ""

        TestKovan ->
            Debug.todo ""

        TestMainnet ->
            Eth.Utils.unsafeToAddress "0x6B175474E89094C44Da98b954EedeAC495271d0F"

        TestGanache ->
            Eth.Utils.unsafeToAddress "0x2612Af3A521c2df9EAF28422Ca335b04AdF3ac66"


fryAddress : TestMode -> Address
fryAddress testMode =
    case testMode of
        None ->
            Debug.todo ""

        TestKovan ->
            Debug.todo ""

        TestMainnet ->
            Eth.Utils.unsafeToAddress "0x47F99F44b140DF9F0eC89631f4265FeE72321Cb9"

        TestGanache ->
            Eth.Utils.unsafeToAddress "0x67B5656d60a809915323Bf2C40A8bEF15A152e3e"


bucketSaleAddress : TestMode -> Address
bucketSaleAddress testMode =
    case testMode of
        None ->
            Debug.todo ""

        TestKovan ->
            Debug.todo ""

        TestMainnet ->
            Eth.Utils.unsafeToAddress "0x1D86DaA6CAeD0913F273E37791D00dc54EAaFc0D"

        TestGanache ->
            Eth.Utils.unsafeToAddress "0x26b4AFb60d6C903165150C6F0AA14F8016bE4aec"


bucketSaleScriptsAddress : TestMode -> Address
bucketSaleScriptsAddress testMode =
    case testMode of
        None ->
            Debug.todo ""

        TestKovan ->
            Debug.todo ""

        TestMainnet ->
            Eth.Utils.unsafeToAddress "0x487Ac5423555B1D83F5b8BA13F260B296E9D0777"

        TestGanache ->
            Eth.Utils.unsafeToAddress "0xA57B8a5584442B467b4689F1144D269d096A3daF"


bucketSaleBucketInterval : TestMode -> Time.Posix
bucketSaleBucketInterval testMode =
    Time.millisToPosix <| 1000 * 60 * 60 * 7


bucketSaleTokensPerBucket : TestMode -> TokenValue
bucketSaleTokensPerBucket testMode =
    TokenValue.fromIntTokenValue 50000


bucketSaleNumBuckets : Int
bucketSaleNumBuckets =
    1200
