module Routing exposing (FullRoute, PageRoute(..), routeToString, urlToFullRoute)

import Common.Types exposing (..)
import Eth.Types exposing (Address)
import Eth.Utils
import Url exposing (Url)
import Url.Builder
import Url.Parser exposing ((</>), (<?>), Parser)
import Url.Parser.Query


type alias FullRoute =
    { testing : TestMode
    , pageRoute : PageRoute
    , maybeReferrer : Maybe Address
    }


type PageRoute
    = Sale
    | NotFound


fullRouteParser : Parser (FullRoute -> a) a
fullRouteParser =
    Url.Parser.oneOf
        [ Url.Parser.s "testmain" </> Url.Parser.map (FullRoute TestMainnet) (pageRouteParser <?> refQueryParser)
        , Url.Parser.s "testkovan" </> Url.Parser.map (FullRoute TestKovan) (pageRouteParser <?> refQueryParser)
        , Url.Parser.s "testlocal" </> Url.Parser.map (FullRoute TestGanache) (pageRouteParser <?> refQueryParser)
        , Url.Parser.map (FullRoute None) (pageRouteParser <?> refQueryParser)
        ]


pageRouteParser : Parser (PageRoute -> a) a
pageRouteParser =
    Url.Parser.oneOf
        [ Url.Parser.map Sale Url.Parser.top
        ]


routeToString : FullRoute -> String
routeToString fullRoute =
    Url.Builder.absolute
        ((case fullRoute.testing of
            TestMainnet ->
                [ "#", "testmain" ]

            TestKovan ->
                [ "#", "testkovan" ]

            TestGanache ->
                [ "#", "testlocal" ]

            _ ->
                [ "#" ]
         )
            ++ (case fullRoute.pageRoute of
                    Sale ->
                        []

                    NotFound ->
                        []
               )
        )
        (case fullRoute.maybeReferrer of
            Just address ->
                [ Url.Builder.string "ref" (Eth.Utils.addressToChecksumString address) ]

            Nothing ->
                []
        )


addressParser : Parser (Address -> a) a
addressParser =
    Url.Parser.custom
        "ADDRESS"
        (Eth.Utils.toAddress >> Result.toMaybe)


refQueryParser : Url.Parser.Query.Parser (Maybe Address)
refQueryParser =
    Url.Parser.Query.string "ref"
        |> Url.Parser.Query.map (Maybe.andThen (Eth.Utils.toAddress >> Result.toMaybe))


urlToFullRoute : Url -> FullRoute
urlToFullRoute url =
    Maybe.withDefault (FullRoute None NotFound Nothing) (Url.Parser.parse fullRouteParser url)
