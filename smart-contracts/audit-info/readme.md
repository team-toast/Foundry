# Foundry Sale Audit Specification

We request an audit for certain pieces of the code on [the audit branch of the Foundry repo at commit 
32472ae](https://github.com/burnable-tech/Foundry/tree/32472ae77074874e35a44dbd9e02f4a72bd21491). We include three contracts in this audit: [BucketSale.sol](../bucket-sale/), the [FRY token](../fry-token/) and [Forwarder.sol](../forwarder/).

The FRY token was composed from [OpenZeppelin's composeable ERC20 contracts at this specific commit](https://github.com/OpenZeppelin/openzeppelin-contracts/tree/b1e811430a0a57211bdc5d48bee0fe0ba9101139/contracts/token/ERC20). Given that these OpenZeppelin contracts have already been audited, we request verification that the contracts used (included here in common/openzeppelin) were faithfully copied and responsibly composed.

Note that another contract, [Scripts.sol](../bucket-sale/contracts/Scripts.sol), is used by the Bucket Sale interface. However we consider this outside the scope of this audit, as it only interacts with the Bucket Sale as a kind of proxy user, and has no special privileges over any other user.

To get acquainted with the contract and its intended behavior, take a look at these links, see the [high-level description of all intended functionality in the contract](high-level-feature-spec.md).

We've generated a [low-level spec sheet](https://docs.google.com/spreadsheets/d/1FrYTQoqIrHveinfidWCZXEl2wjfKYbSIHz1jvfmIKuA/edit?usp=sharing) (note the tabs along the bottom) and have written [automated tests](../bucket-sale/tests/) corresponding to each entry in the sheet.