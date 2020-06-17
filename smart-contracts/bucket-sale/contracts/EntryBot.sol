pragma solidity ^0.5.17;

//import "./BucketSale.sol";
import "../../common.5/openzeppelin/token/ERC20/IERC20.sol";
import "../../common.5/openzeppelin/math/SafeMath.sol";

contract BucketSale
{
    function tokenSoldFor()
        public
        returns (IERC20);

    function agreeToTermsAndConditionsListedInThisContractAndEnterSale(
        address _buyer,
        uint _bucketId,
        uint _amount,
        address _referrer)
    public;
}

contract EntryBot
{
    using SafeMath for uint256;
    BucketSale bucketSale;

    constructor(BucketSale _bucketSale)
        public
    {
        bucketSale = _bucketSale;
        bucketSale.tokenSoldFor().approve(address(bucketSale), uint(-1));
    }

    function agreeToTermsAndConditionsListedInThisBucketSaleContractAndEnterSale(
            address _buyer,
            uint _bucketId,
            uint _amountPerBucket,
            uint _numberOfBuckets,
            address _referrer)
        public
    {
        bucketSale.tokenSoldFor().transferFrom(msg.sender, address(this), _amountPerBucket.mul(_numberOfBuckets));

        for(uint i = 0; i <= _numberOfBuckets; i++)
        {
            bucketSale.agreeToTermsAndConditionsListedInThisContractAndEnterSale(
                _buyer,
                _bucketId.add(i),
                _amountPerBucket,
                _referrer
            );
        }
    }
}