module Helpers.Http exposing (..)

import Http


errorToString : Http.Error -> String
errorToString err =
    case err of
        Http.Timeout ->
            "Timeout exceeded"

        Http.NetworkError ->
            "Network error"

        Http.BadStatus statusInt ->
            "Bad status: " ++ String.fromInt statusInt

        Http.BadBody str ->
            "Unexpected response from api: " ++ str

        Http.BadUrl url ->
            "Malformed url: " ++ url
