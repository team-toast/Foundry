# Contract Audit: Foundry Smart Contracts

## Preamble

This audit report was undertaken by @adamdossa for the purpose of providing feedback to the Foundry / DAIHard team. It has been written without any express or implied warranty.

The initial audit (see audit.md) was as of as of commit:  
https://github.com/burnable-tech/Foundry/tree/32472ae77074874e35a44dbd9e02f4a72bd21491

The updated audit (see audit_update.md) looked at the differences and responses for the above audit relative to commit:  
https://github.com/burnable-tech/Foundry/tree/3be4370b98697ddfc43317aea03650f91e1df43c

This audit (audit_update_2.md) reviews changes between the previous audit and the commit:  
https://github.com/team-toast/Foundry/tree/f9869c56db9217884afa5d215d1c40855e8c6fc5

## Disclosure

The Reports are not an endorsement or indictment of any particular project or team, and the Reports do not guarantee the security of any particular project. This Report does not consider, and should not be interpreted as considering or having any bearing on, the potential economics of a token, token sale or any other product, service or other asset. Cryptographic tokens are emergent technologies and carry with them high levels of technical risk and uncertainty. No Report provides any warranty or representation to any Third-Party in any respect, including regarding the bugfree nature of code, the business model or proprietors of any such business model, and the legal compliance of any such business. No third party should rely on the Reports in any way, including for the purpose of making any decisions to buy or sell any token, product, service or other asset. Specifically, for the avoidance of doubt, this Report does not constitute investment advice, is not intended to be relied upon as investment advice, is not an endorsement of this project or team, and it is not a guarantee as to the absolute security of the project. There is no owed duty to any Third-Party by virtue of publishing these Reports.

PURPOSE OF REPORTS The Reports and the analysis described therein are created solely for Clients and published with their consent. The scope of our review is limited to a review of Solidity code and only the Solidity code we note as being within the scope of our review within this report. The Solidity language itself remains under development and is subject to unknown risks and flaws. The review does not extend to the compiler layer, or any other areas beyond Solidity that could present security risks. Cryptographic tokens are emergent technologies and carry with them high levels of technical risk and uncertainty.

## Classification

* **Comment** - A note that highlights certain decisions taken and their impact on the contract.
* **Minor** - A defect that does not have a material impact on the contract execution and is likely to be subjective.
* **Moderate** - A defect that could impact the desired outcome of the contract execution in a specific scenario.
* **Major** - A defect that impacts the desired outcome of the contract execution or introduces a weakness that may be exploited.
* **Critical** - A defect that presents a significant security vulnerability or failure of the contract across a range of scenarios.

## Code Summary

These updates were minor in scope - I have listed the material changes below, ignoring changes in comments and non-code text.

Overall none of the changes had issues, beyond one minor non-code comment detailed below.

### Change from Solidity 0.5.11 to 0.5.17

I have reviewed the change lists for these version based on:  
https://github.com/ethereum/solidity/releases

It makes sense to use the most recent version of 0.5.x (which is 0.5.17), although none of the changes or fixed bugs look like they would impact this code in any case.

### Use of Deployer contract to initialise the BucketSale and create the FRY token

A new contract, `Deployer.sol`, has been introduced to manage the initialisation process. I have tested this contract by deploying to Kovan and ensuring that it runs correctly, allocating the correct number of tokens, as well as by careful review of the code.

Overall the code is simple and well-structured, and this seems a good way to deploy these contracts.

One very minor note is that the comment:  
`// 10% given to the governance treasury`  
could be updated to specify an absolute number of tokens, rather than a percentage, as the percentage will depend on the other constructor parameters.

### Use of `MAX_BONUS_PERC` to limit the maximum referral bonus available

Previously the maximum referral bonus was limited to 100% - with this change, this has now been reduced to 20%.

There are no concerns with this change.