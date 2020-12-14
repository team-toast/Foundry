module Types exposing (..)

import BigInt exposing (BigInt)
import Browser
import Browser.Navigation
import BucketSale.Types
import CmdUp exposing (CmdUp)
import CommonTypes exposing (..)
import Eth.Sentry.Tx as TxSentry exposing (TxSentry)
import Eth.Sentry.Wallet as WalletSentry exposing (WalletSentry)
import Eth.Types exposing (Address)
import Http
import Time
import TokenValue exposing (TokenValue)
import Url exposing (Url)
import UserNotice as UN exposing (UserNotice)
import Wallet


type alias Flags =
    { networkId : Int
    , width : Int
    , height : Int
    , nowInMillis : Int
    , maybeReferralAddressString : Maybe String
    , cookieConsent : Bool
    }


type alias Model =
    { key : Browser.Navigation.Key
    , testMode : TestMode

    -- , pageRoute : Routing.PageRoute
    , userAddress : Maybe Address -- `wallet` will store this but only after commPubkey has been generated
    , wallet : Wallet.State
    , now : Time.Posix
    , txSentry : Maybe (TxSentry Msg)
    , submodel : Submodel
    , userNotices : List (UserNotice Msg)
    , dProfile : DisplayProfile
    , maybeReferrer : Maybe Address
    , displayMobileWarning : Bool
    , nonRepeatingGTagsSent : List String
    , cookieConsentGranted : Bool
    }


type Msg
    = NoOp
    | UpdateNow Time.Posix
    | SaleStartTimestampFetched (Result Http.Error BigInt)
    | FetchUserEnteringTokenBalance Address
    | UserEnteringTokenBalanceFetched Address (Result Http.Error TokenValue)
      -- | GotoRoute Routing.PageRoute
    | LinkClicked Browser.UrlRequest
      -- | UrlChanged Url.Url
    | ClickHappened
    | BucketSaleMsg BucketSale.Types.Msg
    | CmdUp (CmdUp Msg)
    | ConnectToWeb3
    | WalletStatus WalletSentry
    | TxSentryMsg TxSentry.Msg
    | Resize Int Int
    | CookieConsentGranted
    | Test String
    | DismissNotice Int


type Submodel
    = LoadingSaleModel BucketSaleLoadingModel
    | BucketSaleModel BucketSale.Types.Model


type alias BucketSaleLoadingModel =
    { loadingState : LoadingState
    , userBalance : Maybe TokenValue
    }


type LoadingState
    = Loading
    | Error BucketSaleError


type BucketSaleError
    = SaleNotDeployed
    | SaleNotStarted Time.Posix
