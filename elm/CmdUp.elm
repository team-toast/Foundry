module CmdUp exposing (..)

import CommonTypes exposing (..)
import Eth.Types exposing (Address)
import Routing
import UserNotice as UN exposing (UserNotice)


type CmdUp msg
    = Web3Connect
    | GotoRoute Routing.PageRoute
    | GTag GTagData
    | NonRepeatingGTag GTagData
    | UserNotice (UserNotice msg)
    | NewReferralGenerated Address


gTag : String -> String -> String -> Int -> CmdUp msg
gTag event category label value =
    GTag <|
        GTagData
            event
            category
            label
            value

nonRepeatingGTag : String -> String -> String -> Int -> CmdUp msg
nonRepeatingGTag event category label value =
    NonRepeatingGTag <|
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
        
        NonRepeatingGTag data ->
            NonRepeatingGTag data

        NewReferralGenerated address ->
            NewReferralGenerated address

        UserNotice userNotice ->
            UserNotice (userNotice |> UN.map f)


mapList : (msg1 -> msg2) -> List (CmdUp msg1) -> List (CmdUp msg2)
mapList f cmdUps =
    List.map
        (map f)
        cmdUps
