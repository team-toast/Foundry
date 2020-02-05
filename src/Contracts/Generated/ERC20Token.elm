module Contracts.Generated.ERC20Token exposing
    ( Approval
    , Transfer
    , allowance
    , approvalDecoder
    , approvalEvent
    , approve
    , balanceOf
    , decimals
    , totalSupply
    , transfer
    , transferDecoder
    , transferEvent
    , transferFrom
    )

import Abi.Decode as AbiDecode exposing (abiDecode, andMap, data, toElmDecoder, topic)
import Abi.Encode as AbiEncode exposing (Encoding(..), abiEncode)
import BigInt exposing (BigInt)
import Eth.Types exposing (..)
import Eth.Utils as U
import Json.Decode as Decode exposing (Decoder, succeed)
import Json.Decode.Pipeline exposing (custom)



{-

   This file was generated by https://github.com/cmditch/elm-ethereum-generator

-}


{-| "allowance(address,address)" function
-}
allowance : Address -> Address -> Address -> Call BigInt
allowance contractAddress tokenOwner spender =
    { to = Just contractAddress
    , from = Nothing
    , gas = Nothing
    , gasPrice = Nothing
    , value = Nothing
    , data = Just <| AbiEncode.functionCall "allowance(address,address)" [ AbiEncode.address tokenOwner, AbiEncode.address spender ]
    , nonce = Nothing
    , decoder = toElmDecoder AbiDecode.uint
    }


{-| "approve(address,uint256)" function
-}
approve : Address -> Address -> BigInt -> Call Bool
approve contractAddress spender tokens =
    { to = Just contractAddress
    , from = Nothing
    , gas = Nothing
    , gasPrice = Nothing
    , value = Nothing
    , data = Just <| AbiEncode.functionCall "approve(address,uint256)" [ AbiEncode.address spender, AbiEncode.uint tokens ]
    , nonce = Nothing
    , decoder = toElmDecoder AbiDecode.bool
    }


{-| "balanceOf(address)" function
-}
balanceOf : Address -> Address -> Call BigInt
balanceOf contractAddress tokenOwner =
    { to = Just contractAddress
    , from = Nothing
    , gas = Nothing
    , gasPrice = Nothing
    , value = Nothing
    , data = Just <| AbiEncode.functionCall "balanceOf(address)" [ AbiEncode.address tokenOwner ]
    , nonce = Nothing
    , decoder = toElmDecoder AbiDecode.uint
    }


{-| "decimals()" function
-}
decimals : Address -> Call BigInt
decimals contractAddress =
    { to = Just contractAddress
    , from = Nothing
    , gas = Nothing
    , gasPrice = Nothing
    , value = Nothing
    , data = Just <| AbiEncode.functionCall "decimals()" []
    , nonce = Nothing
    , decoder = toElmDecoder AbiDecode.uint
    }


{-| "totalSupply()" function
-}
totalSupply : Address -> Call BigInt
totalSupply contractAddress =
    { to = Just contractAddress
    , from = Nothing
    , gas = Nothing
    , gasPrice = Nothing
    , value = Nothing
    , data = Just <| AbiEncode.functionCall "totalSupply()" []
    , nonce = Nothing
    , decoder = toElmDecoder AbiDecode.uint
    }


{-| "transfer(address,uint256)" function
-}
transfer : Address -> Address -> BigInt -> Call Bool
transfer contractAddress to tokens =
    { to = Just contractAddress
    , from = Nothing
    , gas = Nothing
    , gasPrice = Nothing
    , value = Nothing
    , data = Just <| AbiEncode.functionCall "transfer(address,uint256)" [ AbiEncode.address to, AbiEncode.uint tokens ]
    , nonce = Nothing
    , decoder = toElmDecoder AbiDecode.bool
    }


{-| "transferFrom(address,address,uint256)" function
-}
transferFrom : Address -> Address -> Address -> BigInt -> Call Bool
transferFrom contractAddress from to tokens =
    { to = Just contractAddress
    , from = Nothing
    , gas = Nothing
    , gasPrice = Nothing
    , value = Nothing
    , data = Just <| AbiEncode.functionCall "transferFrom(address,address,uint256)" [ AbiEncode.address from, AbiEncode.address to, AbiEncode.uint tokens ]
    , nonce = Nothing
    , decoder = toElmDecoder AbiDecode.bool
    }


{-| "Approval(address,address,uint256)" event
-}
type alias Approval =
    { tokenOwner : Address
    , spender : Address
    , tokens : BigInt
    }


approvalEvent : Address -> Maybe Address -> Maybe Address -> LogFilter
approvalEvent contractAddress tokenOwner spender =
    { fromBlock = LatestBlock
    , toBlock = LatestBlock
    , address = contractAddress
    , topics =
        [ Just <| U.keccak256 "Approval(address,address,uint256)"
        , Maybe.map (abiEncode << AbiEncode.address) tokenOwner
        , Maybe.map (abiEncode << AbiEncode.address) spender
        ]
    }


approvalDecoder : Decoder Approval
approvalDecoder =
    succeed Approval
        |> custom (topic 1 AbiDecode.address)
        |> custom (topic 2 AbiDecode.address)
        |> custom (data 0 AbiDecode.uint)


{-| "Transfer(address,address,uint256)" event
-}
type alias Transfer =
    { from : Address
    , to : Address
    , tokens : BigInt
    }


transferEvent : Address -> Maybe Address -> Maybe Address -> LogFilter
transferEvent contractAddress from to =
    { fromBlock = LatestBlock
    , toBlock = LatestBlock
    , address = contractAddress
    , topics =
        [ Just <| U.keccak256 "Transfer(address,address,uint256)"
        , Maybe.map (abiEncode << AbiEncode.address) from
        , Maybe.map (abiEncode << AbiEncode.address) to
        ]
    }


transferDecoder : Decoder Transfer
transferDecoder =
    succeed Transfer
        |> custom (topic 1 AbiDecode.address)
        |> custom (topic 2 AbiDecode.address)
        |> custom (data 0 AbiDecode.uint)
