High Level Description of Bucket.sol
===

### Buckets

The purpose of this smart contract is to mint and sell `tokenOnSale` (typically a newly minted token) for some other `tokenSoldFor` (typically an established token, such as Dai or wETH) in a series of "buckets". Team Toast will be using this mechanism to sell FRY for Dai, but we have written the contract such that it should work for selling any mintable ERC20 token for any other token, and we request the scope of the audit include this assumption.

Each bucket lasts `bucketPeriod` seconds, set in the constructor and never changed thereafter. For any bucket that is active or in the future, any number of agents can **enter** the bucket by depositing any amount of `tokenSoldFor`. This can be done multiple times to add to the total number of entered tokens on any given bucket. For any bucket in the past, any agent who had entered the bucket can **exit** the bucket, which disburses some number of `tokenOnSale`. The amount of `tokenOnSale` the agent receives is proportional to how much `tokenSoldFor` in total he entered into that bucket, divided by the total number of `tokenSoldFor` was deposited by him and any other agents. For example, if Alice **enter**s a bucket with 10 `tokenSoldFor` and Bob enters with 90, and `bucketSupply` is 1000 `tokenOnSale`, then Alice can exit that bucket to claim 100 `tokenOnSale` while Bob can exit to claim 900.

As DAI is **enter**ed into the sale, it is immediately sent to a treasury. This treasury is the Forwarder contract, whose owner is a secure Team Toast multisig.

The bucket sale is designed to end after `bucketCount` buckets, and will have disbursed up to `bucketSupply * bucketCount`. It is possible the sale will disburse less than this, in the case any buckets receive no **enter**s and thus disburse no tokens.

### Referrals

The **enter** method takes an optional referrer value (optional meaning that 0x0 indicates no referrer). If a non-zero address is supplied, this gives a bonus to the buyer as well as to the referrer, and the referrer's bonus scales with the total amount of `tokenSoldFor` they are responsible for referring. This is expected to be used in the context of an interface that tracks referral data and passes it along silently to the **enter** call.

This bonus takes the form of a "free" entry into the next bucket, proportional to the amount the buyer is entering into the target bucket. The public **enter** function does this by making 3 separate calls to the internal **registerEnter** call: first for the initial "normal" enter, second for the buyer's bonus (10% of the amount they are entering with), and third for the referrer's bonus (10%-100% of the amount the buyer is entering with). The referrer's bonus starts at 10% and increases 1% for every 1000 `tokenSoldFor` the referrer has referred in the past, and caps out at 100%.

A good way to think of this is that the bucket sale "pretends" that the referrer and buyer put in extra DAI into the subsequent bucket even though they did not. Thus the sum of all totalValueEntered for all buckets will therefore be greater than the actual balance captured in the treasury, given that some users use this referral mechanism.

Note that since `registerEnter` reverts on an invalid bucket, attempting to `enter` the last valid bucket with a referrer will also revert, as there will be no "next bucket" to register the bonuses in.