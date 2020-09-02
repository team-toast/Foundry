//
// Attention Auditor:
// We consider this contract outside of the audit scope, given that it
// interacts with the BucketSale contract as an external user and is
// fundamentally limited in the same ways.
//

pragma solidity ^0.5.17;

contract IBucketSale
{
    function exit(uint _bucketId, address _buyer) external;
}

contract MultiExitScript
{
    function exitManyBuyers(
            IBucketSale _bucketSale,
            address[] memory _buyers,
            uint[] memory _bucketIds)
        public
    {
        require(_buyers.length == _bucketIds.length, "tupple mismatch");
        for (uint i = 0; i < _bucketIds.length; i++)
        {
            _bucketSale.exit(_bucketIds[i], _buyers[i]);
        }
    }
}
