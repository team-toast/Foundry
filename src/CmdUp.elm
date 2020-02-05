module CmdUp exposing (CmdUp(..), gTag, map, mapList)

import UserNotice as UN exposing (UserNotice)
import CommonTypes exposing (..)
import Routing


type CmdUp msg
    = Web3Connect
    | GotoRoute Routing.PageRoute
    | GTag GTagData
    | UserNotice (UserNotice msg)


gTag : String -> String -> String -> Int -> CmdUp msg
gTag event category label value =
    GTag <|
        GTagData
            event
            category
            label
            value


map : (msg1 -> msg2) -> CmdUp msg1 -> CmdUp msg2
map f cmdUp =
    case cmdUp of
        Web3Connect ->
            Web3Connect

        GotoRoute route ->
            GotoRoute route

        GTag data ->
            GTag data
        
        UserNotice userNotice ->
            UserNotice (userNotice |> UN.map f)


mapList : (msg1 -> msg2) -> List (CmdUp msg1) -> List (CmdUp msg2)
mapList f cmdUps =
    List.map
        (map f)
        cmdUps
