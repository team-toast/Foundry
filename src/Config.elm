module Config exposing (..)

import BigInt exposing (BigInt)
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


daiContractAddress : Bool -> Address
daiContractAddress testMode =
    if testMode then
        Eth.Utils.unsafeToAddress "0x4F96Fe3b7A6Cf9725f59d353F723c1bDb64CA6Aa"

    else
        Eth.Utils.unsafeToAddress "0x6B175474E89094C44Da98b954EedeAC495271d0F"


fryAddress : Bool -> Address
fryAddress testMode =
    if testMode then
        Eth.Utils.unsafeToAddress "0x4F1bee416CEcB7Bc3d4A0b94F78e401fb664F4eF"

    else
        Eth.Utils.unsafeToAddress "0x47F99F44b140DF9F0eC89631f4265FeE72321Cb9"


bucketSaleAddress : Bool -> Address
bucketSaleAddress testMode =
    if testMode then
        Eth.Utils.unsafeToAddress "0xAa3A3eABE664f873B5FF6eC10967C3e619a0a764"

    else
        Eth.Utils.unsafeToAddress "0x1D86DaA6CAeD0913F273E37791D00dc54EAaFc0D"


bucketSaleScriptsAddress : Bool -> Address
bucketSaleScriptsAddress testMode =
    if testMode then
        Eth.Utils.unsafeToAddress "0x9439E2755CaA6C97CD1AAE82FA97Ce91c93d9137"

    else
        Eth.Utils.unsafeToAddress "0x487Ac5423555B1D83F5b8BA13F260B296E9D0777"


bucketSaleBucketInterval : Bool -> Time.Posix
bucketSaleBucketInterval testMode =
    if testMode then
        Time.millisToPosix <| 1000 * 60 * 60 * 7

    else
        Time.millisToPosix <| 1000 * 60 * 60 * 7


bucketSaleTokensPerBucket : Bool -> TokenValue
bucketSaleTokensPerBucket testMode =
    if testMode then
        TokenValue.fromIntTokenValue 50000

    else
        TokenValue.fromIntTokenValue 50000


bucketSaleNumBuckets : Int
bucketSaleNumBuckets =
    1200
