module Home.View exposing (root)

import Images
import CommonTypes exposing (..)
import Element exposing (Element)
import Element.Font
import Helpers.Element as EH
import Markdown
import Types exposing (..)


root : DisplayProfile -> Element Msg
root dProfile =
    EH.simpleSubmodelContainer
        1000
    <|
        Element.column
            [ Element.width Element.fill
            , Element.padding 20
            ]
            [ markdownToEl
                """# Team Toast

Team Toast is a small team centered around the development of DAIHard and Foundry. More info on us coming soon! In the mean time feel free to follow our [Medium publication](https://medium.com/daihard-buidlers).

# Foundry

Team Toast is building a DAO called **Foundry**. Foundry's initial purpose is to take over DAIHard stewardship, as this would extend DAIHard's unkillable nature to its very development and maintenance. Foundry will likely build similar products in the future: for-profit, unkillable tools that increase global financial freedom, which fragile meatbags are unwilling to own and manage directly."""
            , Images.foundrySchematic
                |> Images.toElement
                [ Element.width Element.fill]
                
            , markdownToEl
                """We will be publishing more details soon, both on Foundry's structure and on the sale's mechanics. We are also excited to share the "piecewise" strategy of DAO development, analagous to the lean methodology for start-ups.

To hear about these updates, subscribe to our [Medium publication](https://medium.com/daihard-buidlers).

# DAIHard

DAIHard is Team Toast's flagship product. It is an unkillable, global gateway from any currency (fiat or crypto) to and from Dai. It can can be used pseudonymously and without KYC, and is built specifically to survive unfriendly jurisdictions (i.e. Zimbabwe). It is built entirely on Ethereum smart contracts, and involves no third parties to operate (not even escrow agents). This is achieved chiefly via the game theory of Burnable Payments, which we've written about [here](https://medium.com/@coinop.logan/daihard-game-theory-21a456ef224e). See also our launch post [here](https://www.reddit.com/r/ethereum/comments/chl924/relaunching_the_borderless_unkillable_cryptofiat/) for more on DAIHard and the problems it solves.

DAIHard is currently [live on mainnet](https://daihard.exchange), but lacks liquidity. Marketing and liquidity will be a major use of the funding from the Foundry sale.

Questions or comments? [Join the DAIHard Telegram](https://t.me/daihardexchange_group)!

# ZimDai

ZimDai is a thorough investigation into the viability of boostrapping Dai adoption in Zimbabwe, given the significant challenges any such endeavor faces today. It is the result of two months of on-the-ground research by Logan, funded by Team Toast, to analyze the market fit between DAIHard and the Zimbabwean market.

This research has been decoupled from reliance on DAIHard and distilled into [The ZimDai Paper: A Blueprint for an Economic Jailbreak](https://github.com/coinop-logan/ZimDai/raw/master/whitepaper.pdf). As this paper was publicized and passed around, no major flaws were uncovered. Please take a look with a critical eye, and join the Telegram (link in paper) with any thoughts or questions. At this point, the only missing piece seems to be a marketing drive--both leadership and funding.

Given a marketing drive, we may have on our hands a strikingly realistic, immediately applicable plan to liberate the Zimbabwean citizenry from systemic financial abuse. This has been a dream within crypto for years. Perhaps today crypto can begin making these kinds of significant moves on the global stage.

If the Foundry sale accumulates significant funding, it could decide to step into this gap, funding and leading the ZimDai movement. We will share more thoughts on this soon, again via our [Medium publication](https://medium.com/daihard-buidlers)."""
            ]


markdownToEl : String -> Element Msg
markdownToEl =
    Markdown.toHtml Nothing
        >> List.map Element.html
        >> List.map
            (Element.paragraph
                [ Element.width Element.fill ]
                << List.singleton
            )
        >> Element.column [ Element.width Element.fill ]






-- bulletListWithHeader : String -> DisplayProfile -> List (Element Msg) -> Element Msg
-- bulletListWithHeader title dProfile els =
--     let
--         bulletEl =
--             Element.el
--                 [ Element.Font.size (20 |> changeForMobile 16 dProfile) ]
--                 (Element.text EH.bulletPointString)
--     in
--     Element.column
--         [ Element.spacing (20 |> changeForMobile 10 dProfile) ]
--         [ Element.el
--             [ Element.Font.size 24
--             , Element.Font.bold
--             ]
--             (Element.text title)
--         , Element.column
--             [ Element.spacing (20 |> changeForMobile 10 dProfile)
--             ]
--             (els
--                 |> List.map
--                     (\itemEl ->
--                         Element.row
--                             []
--                             [ Element.el
--                                 [ Element.spacingXY 20 0 ]
--                                 bulletEl
--                             , itemEl
--                             ]
--                     )
--             )
--         ]
