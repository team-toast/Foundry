This is a short document intended for potential auditors, that collects all of our security analysis and documentation, and describes specifically what we are looking for in an audit.

To get acquainted with the contract and its intended behavior, take a look at these links:
- ANNOUNCE POST NEEDED
- [High-level description of all intended functionality in the contract](high-level-feature-spec.md)

The version of the contract to audit can be seen here https://github.com/burnable-tech/Foundry/blob/dev/smart-contracts/bucket-sale/contracts/Bucket.sol

We've generated a low-level spec sheet and automated tests for crucial functions. 
https://docs.google.com/spreadsheets/d/1FrYTQoqIrHveinfidWCZXEl2wjfKYbSIHz1jvfmIKuA/edit#gid=0

### Assumptions

- The Sale is started with all the tokens on sale it will need to disburse throughout the sale - specifically, it will be given a balance of (bucketCount * bucketSupply) upon instantiation.
- The owner, who can withdraw funds from the bucket sale, is a Gnosis Safe multisig.
- Referral rewards are entered into the bucket after the bucket that is being purchased from.
