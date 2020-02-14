# Foundry Sale Audit Specification

We request an audit for certain pieces of the code on [this specific commit of this repo LINK NEEDED](LINKNEEDED). We include three contracts in this audit: [BucketSale.sol](bucket-sale/), the [FRY token](fry-token/) and [Forwarder.sol](forwarder/).

The FRY token was composed from [OpenZeppelin's composeable ERC20 contracts](https://github.com/OpenZeppelin/openzeppelin-contracts/tree/master/contracts/token/ERC20). Given that these OpenZeppelin contracts have already been audited, we request verification that the contracts used (included in common/openzeppelin) were faithfully copied and responsibly composed. (DO WE USE flattened file or redeploy from truffle?)

Note that another contract, [Scripts.sol](bucket-sale/contracts/Scripts.sol), is used by the Bucket Sale interface. However we consider this outside the scope of this audit, as it only interacts with the Bucket Sale as a kind of proxy user, and has no special privileges over any other user.

To get acquainted with the contract and its intended behavior, take a look at these links:
- ANNOUNCE POST NEEDED
- [High-level description of all intended functionality in the contract](high-level-feature-spec.md)

We've generated a [low-level spec sheet](https://docs.google.com/spreadsheets/d/1FrYTQoqIrHveinfidWCZXEl2wjfKYbSIHz1jvfmIKuA/edit?usp=sharing) (note the tabs along the bottom) and have written [automated tests](bucket-sale/tests/) corresponding to each entry in the sheet.

While we consider the interface outside the scope of this audit, the auditor can see a mainnet demo (disbursing fake FRY) [here LINK NEEDED](LINKNEEDED). We suggest using e.g. 0.01 DAI if the auditor would like to get a feel for the intended usage. We are happy to forward any DAI spent in this way back to the auditor upon request.

### Assumptions

- The Sale is started with all the tokens on sale it will need to disburse throughout the sale - specifically, it will be given a balance of (bucketCount * bucketSupply) upon instantiation. In our case this value is 60m FRY (or 6*10^25 base 'uint' units).