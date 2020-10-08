module Config exposing (..)

import BigInt exposing (BigInt)
import CommonTypes exposing (..)
import Eth.Types exposing (Address)
import Eth.Utils
import Set exposing (Set)
import Time
import TokenValue exposing (TokenValue)


mainnetHttpProviderUrl : String
mainnetHttpProviderUrl =
    "https://4eaf7efe792b417e816294ad07d323c4.eth.rpc.rivet.cloud/"


kovanHttpProviderUrl : String
kovanHttpProviderUrl =
    "https://kovan.infura.io/v3/e3eef0e2435349bf9164e6f465bd7cf9"


ganacheProviderUrl : String
ganacheProviderUrl =
    "http://localhost:8545"


appTitle : String
appTitle =
    "Foundry Permafrost - Locked Liquidity Experiment"


enteringTokenCurrencyLabel : String
enteringTokenCurrencyLabel =
    "ETHFRY"


enteringTokenImageInfo : { src : String, description : String }
enteringTokenImageInfo =
    { src = "img/liq-symbol.svg"
    , description = "balancer liquidity token"
    }


enteringTokenAddress : TestMode -> Address
enteringTokenAddress testMode =
    case testMode of
        None ->
            Eth.Utils.unsafeToAddress "0x5277a42ef95ECa7637fFa9E69B65A12A089FE12b"

        TestKovan ->
            Debug.todo ""

        TestMainnet ->
            Debug.todo ""

        TestGanache ->
            Debug.todo ""


exitingTokenCurrencyLabel : String
exitingTokenCurrencyLabel =
    "FRY"


exitingTokenAddress : TestMode -> Address
exitingTokenAddress testMode =
    case testMode of
        None ->
            Eth.Utils.unsafeToAddress "0x6c972b70c533E2E045F333Ee28b9fFb8D717bE69"

        TestKovan ->
            Debug.todo ""

        TestMainnet ->
            Eth.Utils.unsafeToAddress "0xe8c7495870f63DD045ba20E4604Ef3534ffa3724"

        TestGanache ->
            Eth.Utils.unsafeToAddress "0x67B5656d60a809915323Bf2C40A8bEF15A152e3e"


bucketSaleAddress : TestMode -> Address
bucketSaleAddress testMode =
    case testMode of
        None ->
            Eth.Utils.unsafeToAddress "0x254c2378511a694403c7A8589Ec9D8f0E11D49A7"

        TestKovan ->
            Debug.todo ""

        TestMainnet ->
            Debug.todo ""

        TestGanache ->
            Debug.todo ""


bucketSaleScriptsAddress : TestMode -> Address
bucketSaleScriptsAddress testMode =
    case testMode of
        None ->
            Eth.Utils.unsafeToAddress "0xf0B2B0A7bcd35cc119E12Cf4F04B2739Ac400bef"

        TestKovan ->
            Debug.todo ""

        TestMainnet ->
            Eth.Utils.unsafeToAddress "0xf0B2B0A7bcd35cc119E12Cf4F04B2739Ac400bef"

        TestGanache ->
            Debug.todo ""


gasstationApiEndpoint : String
gasstationApiEndpoint =
    "https://ethgasstation.info/api/ethgasAPI.json?api-key=ebca374685809a499c4513455cb6867c6112269da20bda9ae64d491a02cf"


bucketSaleBucketInterval : TestMode -> Time.Posix
bucketSaleBucketInterval testMode =
    Time.millisToPosix <| 1000 * 60 * 60 * 42


bucketSaleTokensPerBucket : TestMode -> TokenValue
bucketSaleTokensPerBucket testMode =
    TokenValue.fromIntTokenValue 225000


bucketSaleNumBuckets : Int
bucketSaleNumBuckets =
    4


feedbackEndpointUrl : String
feedbackEndpointUrl =
    "https://personal-rxyx.outsystemscloud.com/SaleFeedbackUI/rest/General/SubmitFeedback"


ipCountryCodeEndpointUrl : String
ipCountryCodeEndpointUrl =
    "https://personal-rxyx.outsystemscloud.com/SaleFeedbackUI/rest/General/IPCountryLookup"


forbiddenJurisdictionCodes : Set String
forbiddenJurisdictionCodes =
    Set.fromList [ "US" ]
