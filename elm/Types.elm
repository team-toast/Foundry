module Types exposing (..)

import Browser
import Browser.Navigation
import BucketSale.Types
import CmdUp exposing (CmdUp)
import CommonTypes exposing (..)
import Eth.Sentry.Tx as TxSentry exposing (TxSentry)
import Eth.Sentry.Wallet as WalletSentry exposing (WalletSentry)
import Eth.Types exposing (Address)
import Http
import Routing
import Time
import Url exposing (Url)
import UserNotice as UN exposing (UserNotice)
import Wallet


type alias Flags =
    { networkId : Int
    , width : Int
    , height : Int
    , nowInMillis : Int
    , maybeReferralAddressString : Maybe String
    }


type alias Model =
    { key : Browser.Navigation.Key
    , testMode : TestMode
    , pageRoute : Routing.PageRoute
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
    }


type Msg
    = NoOp
    | GotoRoute Routing.PageRoute
    | LinkClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | ClickHappened
    | BucketSaleMsg BucketSale.Types.Msg
    | Tick Time.Posix
    | CmdUp (CmdUp Msg)
    | ConnectToWeb3
    | WalletStatus WalletSentry
    | TxSentryMsg TxSentry.Msg
    | Resize Int Int
    | Test String
    | DismissNotice Int


type Submodel
    = NullSubmodel
    | BucketSaleModel BucketSale.Types.Model
