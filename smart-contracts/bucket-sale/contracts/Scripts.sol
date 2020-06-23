//
// Attention Auditor:
// We consider this contract outside of the audit scope, given that it
// interacts with the BucketSale contract as an external user and is
// fundamentally limited in the same ways.
//

pragma solidity ^0.5.17;

import "./BucketSale.sol";

contract Scripts {
    using SafeMath for uint;

    function getExitInfo(BucketSale _bucketSale, address _buyer)
        public
        view
        returns (uint[1201] memory)
        // The structure here is that the first element contains the sum of exitable tokens and the rest are the indices of the
        // buckets the buyer can exit from
    {
        // goal:
        // 1. return the total FRY the buyer can extract
        // 2. return the bucketIds of each bucket they can extract from

        // logic:
        // *loop over all concluded buckets
        //   *check the .buys for this _buyer
        //   *if there is a buy
        //      *add buy amount to the first array element
        //      *append the bucketId to the array

        uint[1201] memory results; // some gas to allocate this memory * 1201
        uint pointer = 0;

        // mutlipy the loop gas by at least _bucketSale.currentBucket()
        for (uint bucketId = 0; bucketId < Math.min(_bucketSale.currentBucket(), _bucketSale.bucketCount()); bucketId = bucketId.add(1))
        {
            // mapping lookup cost
            // does this differ for empty and non-empty values?
            (uint valueEntered, uint buyerTokensExited) = _bucketSale.buys(bucketId, _buyer);

            if (valueEntered > 0 && buyerTokensExited == 0) {
                // some basic set of gas, all memory related.
                // is there any sort of optimization which may play a role here?

                // update the running total for this buyer
                // this involves 2 mapping lookups again.
                results[0] = results[0]
                    .add(_bucketSale.calculateExitableTokens(bucketId, _buyer));

                // append the bucketId to the results array
                pointer = pointer.add(1);
                results[pointer] = bucketId;
            }
        }

        return results;
    }

    function getGeneralInfo(BucketSale _bucketSale, address _buyer, uint _bucketId)
        public
        view
        returns (
            uint _totalExitedTokens,
            uint _bucket_totalValueEntered,
            uint _buy_valueEntered,
            uint _buy_buyerTokensExited,
            uint _tokenSoldForAllowance,
            uint _tokenOnSaleBalance,
            uint[1201] memory _exitInfo)
    {
        _totalExitedTokens = _bucketSale.totalExitedTokens();
        _bucket_totalValueEntered = _bucketSale.buckets(_bucketId);
        (_buy_valueEntered, _buy_buyerTokensExited) = _bucketSale.buys(_bucketId, _buyer);
        _tokenSoldForAllowance = _bucketSale.tokenSoldFor().allowance(_buyer, address(_bucketSale));
        _tokenOnSaleBalance = _bucketSale.tokenOnSale().balanceOf(_buyer);
        _exitInfo = getExitInfo(_bucketSale, _buyer);
    }

    function exitMany(
            BucketSale _bucketSale,
            address _buyer,
            uint[] memory bucketIds)
        public
    {
        for (uint bucketIdIter = 0; bucketIdIter < bucketIds.length; bucketIdIter = bucketIdIter.add(1))
        {
            _bucketSale.exit(bucketIds[bucketIdIter], _buyer);
        }
    }
}
