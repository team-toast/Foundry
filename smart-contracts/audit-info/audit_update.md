# Contract Audit: Foundry Smart Contracts

## Preamble

This audit report was undertaken by @adamdossa for the purpose of providing feedback to the Foundry / DAIHard team. It has been written without any express or implied warranty.

The initial audit (see audit.md) was as of as of commit:
https://github.com/burnable-tech/Foundry/tree/32472ae77074874e35a44dbd9e02f4a72bd21491

This review looks at the differences and responses for the above audit relative to commit:  
https://github.com/burnable-tech/Foundry/tree/3be4370b98697ddfc43317aea03650f91e1df43c

See "Update" sections for updated comments.

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

Overall the code was well-commented and alongside the explanatory documents at:
https://github.com/burnable-tech/Foundry/blob/audit/smart-contracts/audit-info/high-level-feature-spec.md
was clear in its intent.

Update:

Other than `BucketSale.sol`, the `Forwarder.sol` and `FRY.sol` contracts were also reviewed. Both `Forwarder.sol` and `FRY.sol` contracts had no issues found during audit.

## BucketSale.sol

BucketSale is the main contract that orchestrates the token distribution.

### Issues

**Comment** - Reduce on-chain transactions

Since the intent is to receive DAI, you could use the DAI contracts `permit` function:
```
function permit(address holder, address spender, uint256 nonce, uint256 expiry,
                bool allowed, uint8 v, bytes32 r, bytes32 s)
```

This would remove the need for the `approve` step when sending DAI to the contract. You could also consider adding a similar function to FRY for future convenience.

You can make this an additional entry point into the contract, and therefore still work with other ERC20 tokens.

Update:

The decision was made to not utilise the `permit` function due to time and project scope constraints.

**Minor** - Validate constructor parameters

The constructor should enforce the following constraints:
```
require(_bucketPeriod > 0)
require(_startOfSale > now)
require(_bucketSupply > 0)
require(_bucketCount > 0)
require(_tokenOnSale != address(0) && _tokenSoldFor != address(0))
```

Update:  

This issue has now been resolved following the above suggestion.

**Minor** - Validate enter parameters

The `agreeToTermsAndConditionsListedInThisContractAndEnterSale` function should enforce the following constraints:
```
require(_buyer != address(0))
require(_amount != 0)
```

Update:

The check for a non-zero amount has been implemented. The check for a non-zero buyer will be done in the dApp rather than contract.

**Comment** - Transfer tokens ahead of state updates

In the `agreeToTermsAndConditionsListedInThisContractAndEnterSale` function internal state is updated before the tokens are transferred into the contract:
```
registerEnter(_bucketId, _buyer, _amount);
referredTotal[_referrer] = referredTotal[_referrer].add(_amount); // referredTotal[0x0] will track buys with no referral
bool transferSuccess = tokenSoldFor.transferFrom(msg.sender, treasury, _amount);
```

The external call to `tokenSoldFor` allows a possible re-entrancy into the contract.

Although you could re-enter the contract I can't see any possible exploit since the `exit` function only allows exiting historical buckets which can no longer be entered/

Best practice would be to move the `transferFrom` before the relevant state changes though, in case of a future change to the code.

Update:

This issue has now been resolved following the above suggestion.

**Comment** - Referrals fail in the last bucket

In the protocol description you note:
"Note that since registerEnter reverts on an invalid bucket, attempting to enter the last valid bucket with a referrer will also revert, as there will be no "next bucket" to register the bonuses in."

You may want to consider simply bypassing the referral bonus in this case, rather than reverting. This will simplify UX as users won't need to differentiate between the two situations (last bucket vs. all other buckets).

Update:

The last bucket will be treated as a "leftover" bucket just for referrals rather than direct purchases, and this will be managed via the dApp.

**Comment** - Could default empty referrer

In the `agreeToTermsAndConditionsListedInThisContractAndEnterSale` you could default an empty `_referrer` to `msg.sender`. This is the rational choice for someone who hasn't been referred as they would receive both the referral and their referree bonus.

Update:

The interface currently detects this and prompts the user to create a referral link, which we hope will inspire people to spread their referral link.

**Comment** - Consider emitting `Entered` for referral purchases

It might be reasonable to expect the `Entered` events to reconcile against the contract storage (e.g. `buckets`, `buys`), but since it is not emitted for a referral purchase:
```
registerEnter(_bucketId.add(1), _buyer, buyerReferralReward);
registerEnter(_bucketId.add(1), _referrer, referrerReferralReward);
```
there will be a discrepancy. There would be an additional gas cost to this however.

Update:

Since the `Entered` event captures the `_referrerReferralReward` balances can be reconstructed from this single event.

**Comment** - Unnecessary check in `referrerReferralRewardPerc`

The function `referrerReferralRewardPerc` checks whether `_referrerAddress` is `address(0)` but the only on-chain function that calls this function is `agreeToTermsAndConditionsListedInThisContractAndEnterSale` already has this check.

This does add a small additional gas cost.

Update:

This was left as is, as the function is also used in a read-only query contract.

**Minor** - Assuming DAI is `tokenSoldFor`

The audit document states:
"we have written the contract such that it should work for selling any mintable ERC20 token for any other token, and we request the scope of the audit include this assumption"

In the function `referrerReferralRewardPerc` you assume the token has 18 decimals. For example if it had `6` decimals, dividing by 10^18 would effectively set most referal contributions to 0:
```
uint daiContributed = referredTotal[_referrerAddress].div(10 ** 18);
```
This assumes it is DAI (in terms of variable naming and 18 decimals).

The implied referral cap of 100,000 in this function also assumes this is a reasonable value which may not be true for another ERC20 token. You could consider taking this value as a contract parameter instead.

Update:

The code has been amended to read the decimals from the ERC20 token contract directly via the `IDecimals` interface. The code still assumes that 100,000 is a reasonable referral limit, and the variable names reference DAI which may be confusing.

**Comment** - Reduce exit gas cost

The `exit` function updates the global storage `totalExitedTokens`. This storage is never read anywhere in the contract, and could be reconstructed off-chain from looking at the event history.

Removing this variable would reduce the gas cost of the `exit` transaction by ~5,000.

Update:

This was left as is, as the function is also used in a read-only query contract.

**Moderate** - Referal scheme can be trustlessly gamed

It would be possible to construct a smart contract, `Referrer`, which anyone could call to enter the BucketSale on their behalf (having previously approved `Referrer` to spend their DAI). This contract would specify itself as it's own referrer, thus building up the maximum referral bonus. The final referral bonus for `Referrer` could then be shared trustlessly and proportionally amongst its callers once a bucket has ended.

Entering the sale through this contract, rather than using an actual referrer, would then become the optimal choice (I think) for a user.

Update:

Whilst it is possible to game the contract with this approach, there is a significant barrier to doing so (constructing the contract and UI and promoting it) and in these circumstances the implication is that the fund raise has been successful in any case.

## General Comments

It seems a little unusual to allow people to enter future buckets, rather than just the current bucket.

Because of the way your final ticket allowance is calculated in `calculateExitableTokens` this seems to mean I should enter the future bucket which I think will have least other entries by the time the bucket closes. This seems to introduce possible gaming mechanics, and could cause users to try and optimise the timing of their transactions to the contract.

Update:

The most rational approach is to enter the current bucket as there will be most information available about that bucket (assuming everyone is somewhat rational). If users do enter future buckets rather than the current bucket, there is no obvious downside for the fund raise and the user is taking a risk that the future bucket may end up more popular than the current bucket, which is their risk to take.

## Tests

Test cases were provided alongside the smart contracts, and successfully run to completion with no failure as part of this audit. They seem comprehensive.
