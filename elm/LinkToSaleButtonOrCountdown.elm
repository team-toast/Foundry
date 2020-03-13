module LinkToSaleButtonOrCountdown exposing (main)

import Browser
import Browser.Navigation
import CommonTypes exposing (..)
import Element
import Element.Background
import Element.Border
import Element.Font
import Helpers.Element as EH
import Helpers.Time as TimeHelpers
import Html exposing (Html)
import Html.Attributes
import Http
import Time


main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }


type alias Model =
    { saleStartTime : Time.Posix
    , now : Time.Posix
    }


type alias Flags =
    { saleStartTime : Int
    , now : Int
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( { saleStartTime = TimeHelpers.secondsToPosix flags.saleStartTime
      , now = TimeHelpers.secondsToPosix flags.now
      }
    , Cmd.none
    )


type Msg
    = UpdateNow Time.Posix
    | GotoSale


update : Msg -> Model -> ( Model, Cmd Msg )
update msg prevModel =
    case msg of
        UpdateNow newNow ->
            ( { prevModel | now = newNow }
            , Cmd.none
            )

        GotoSale ->
            ( prevModel
            , Browser.Navigation.load "https://sale.foundrydao.com"
            )


subscriptions : Model -> Sub Msg
subscriptions model =
    Time.every 500 UpdateNow


view : Model -> Html Msg
view model =
    let
        timeUntilSale =
            TimeHelpers.sub
                model.saleStartTime
                model.now

        saleHasStarted =
            TimeHelpers.isNegative timeUntilSale
    in
    Element.layout
        []
    <|
        if saleHasStarted then
            EH.redButton
                Desktop
                []
                [ "Get FRY" ]
                GotoSale

        else
            Element.el [ Element.height <| Element.px 40 ] <|
                Element.text <|
                    "Sale begins in "
                        ++ TimeHelpers.toConciseIntervalString timeUntilSale
