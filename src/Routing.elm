module Routing exposing (FullRoute, PageRoute(..), routeToString, urlToFullRoute)

import Eth.Types exposing (Address)
import Eth.Utils
import Url exposing (Url)
import Url.Builder
import Url.Parser exposing ((</>), (<?>), Parser)
import Url.Parser.Query


type alias FullRoute =
    { testing : Bool
    , pageRoute : PageRoute
    , maybeReferrer : Maybe Address
    }


type PageRoute
    = Home
    | Sale
    | NotFound


fullRouteParser : Parser (FullRoute -> a) a
fullRouteParser =
    Url.Parser.oneOf
        [ Url.Parser.s "test" </> Url.Parser.map (FullRoute True) (pageRouteParser <?> refQueryParser)
        , Url.Parser.map (FullRoute False) (pageRouteParser <?> refQueryParser)
        ]


pageRouteParser : Parser (PageRoute -> a) a
pageRouteParser =
    Url.Parser.oneOf
        [ Url.Parser.map Home Url.Parser.top
        , Url.Parser.map Sale (Url.Parser.s "sale")
        ]


routeToString : FullRoute -> String
routeToString fullRoute =
    Url.Builder.absolute
        ((if fullRoute.testing then
            [ "#", "test" ]

          else
            [ "#" ]
         )
            ++ (case fullRoute.pageRoute of
                    Home ->
                        []

                    Sale ->
                        [ "sale" ]

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
    Maybe.withDefault (FullRoute False NotFound Nothing) (Url.Parser.parse fullRouteParser url)
