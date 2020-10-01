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
    Debug.todo ""


kovanHttpProviderUrl : String
kovanHttpProviderUrl =
    Debug.todo ""


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
            Debug.todo ""

        TestGanache ->
            Debug.todo ""


fryAddress : TestMode -> Address
fryAddress testMode =
    case testMode of
        None ->
            Debug.todo ""

        TestKovan ->
            Debug.todo ""

        TestMainnet ->
            Debug.todo ""

        TestGanache ->
            Debug.todo ""


bucketSaleAddress : TestMode -> Address
bucketSaleAddress testMode =
    case testMode of
        None ->
            Debug.todo ""

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
            Debug.todo ""

        TestKovan ->
            Debug.todo ""

        TestMainnet ->
            Debug.todo ""

        TestGanache ->
            Debug.todo ""


gasstationApiEndpoint : String
gasstationApiEndpoint =
    Debug.todo ""


bucketSaleBucketInterval : TestMode -> Time.Posix
bucketSaleBucketInterval testMode =
    Debug.todo ""


bucketSaleTokensPerBucket : TestMode -> TokenValue
bucketSaleTokensPerBucket testMode =
    Debug.todo ""


bucketSaleNumBuckets : Int
bucketSaleNumBuckets =
    Debug.todo ""
 

feedbackEndpointUrl : String
feedbackEndpointUrl =
    "https://personal-rxyx.outsystemscloud.com/SaleFeedbackUI/rest/General/SubmitFeedback"

ipCountryCodeEndpointUrl : String
ipCountryCodeEndpointUrl =
    "https://personal-rxyx.outsystemscloud.com/SaleFeedbackUI/rest/General/IPCountryLookup"


forbiddenJurisdictionCodes : Set String
forbiddenJurisdictionCodes =
    Set.fromList [ "US" ]
