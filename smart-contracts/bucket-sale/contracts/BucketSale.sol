pragma solidity ^0.5.11;

import "../../common/openzeppelin/math/Math.sol";
import "../../common/openzeppelin/math/SafeMath.sol";
import "../../common/openzeppelin/token/ERC20/ERC20Mintable.sol";

contract BucketSale
{
    using SafeMath for uint256;

    // When passing around bonuses, we use 3 decimals of precision.
    uint constant HUNDRED_PERC = 100000;
    uint constant ONE_PERC = 1000;

    /*
    Every pair of (uint bucketId, address buyer) identifies exactly one 'buy'.
    This buy tracks how much tokenSoldFor the user has entered into the bucket,
    and how much tokenOnSale the user has exited with.
    */

    struct Buy
    {
        uint valueEntered;
        uint buyerTokensExited;
    }

    mapping (uint => mapping (address => Buy)) public buys;

    /*
    Each Bucket tracks how much tokenSoldFor has been entered in total;
    this is used to determine how much tokenOnSale the user can later exit with.
    */

    struct Bucket
    {
        uint totalValueEntered;
    }

    mapping (uint => Bucket) public buckets;

    // For each address, this tallies how much tokenSoldFor the address is responsible for referring.
    mapping (address => uint) public referredTotal;

    address public treasury;
    uint public startOfSale;
    uint public bucketPeriod;
    uint public bucketSupply;
    uint public bucketCount;
    uint public totalExitedTokens;
    ERC20Mintable public tokenOnSale;       // we assume the bucket sale contract has minting rights for this contract
    IERC20 public tokenSoldFor;

    constructor (
            address _treasury,
            uint _startOfSale,
            uint _bucketPeriod,
            uint _bucketSupply,
            uint _bucketCount,
            ERC20Mintable _tokenOnSale,    // FRY in our case
            IERC20 _tokenSoldFor)    // typically DAI
        public
    {
        treasury = _treasury;
        startOfSale = _startOfSale;
        bucketPeriod = _bucketPeriod;
        bucketSupply = _bucketSupply;
        bucketCount = _bucketCount;
        tokenOnSale = _tokenOnSale;
        tokenSoldFor = _tokenSoldFor;
    }

    function timestamp() public view returns (uint256 _now) { return block.timestamp; }

    function currentBucket()
        public
        view
        returns (uint)
    {
        return timestamp().sub(startOfSale).div(bucketPeriod);
    }

    event Entered(
        address _sender,
        uint256 _bucketId,
        address indexed _buyer,
        uint _valueEntered,
        uint _buyerReferralReward,
        address indexed _referrer,
        uint _referrerReferralReward);
    function enter(
            address _buyer,
            uint _bucketId,
            uint _amount,
            address _referrer)
        public
    {
        registerEnter(_bucketId, _buyer, _amount);
        referredTotal[_referrer] = referredTotal[_referrer].add(_amount); // referredTotal[0x0] will track buys with no referral
        bool transferSuccess = tokenSoldFor.transferFrom(msg.sender, treasury, _amount);
        require(transferSuccess, "enter transfer failed");

        if (_referrer != address(0)) // If there is a referrer
        {
            uint buyerReferralReward = _amount.mul(buyerReferralRewardPerc()).div(HUNDRED_PERC);
            uint referrerReferralReward = _amount.mul(referrerReferralRewardPerc(_referrer)).div(HUNDRED_PERC);

            // Both rewards are registered as buys in the next bucket
            registerEnter(_bucketId.add(1), _buyer, buyerReferralReward);
            registerEnter(_bucketId.add(1), _referrer, referrerReferralReward);

            emit Entered(
                msg.sender,
                _bucketId,
                _buyer,
                _amount,
                buyerReferralReward,
                _referrer,
                referrerReferralReward);
        }
        else
        {
            emit Entered(
                msg.sender,
                _bucketId,
                _buyer,
                _amount,
                0,
                address(0),
                0);
        }
    }

    function registerEnter(uint _bucketId, address _buyer, uint _amount)
        internal
    {
        require(_bucketId >= currentBucket(), "cannot enter past buckets");
        require(_bucketId < bucketCount, "invalid bucket id--past end of sale");

        Buy storage buy = buys[_bucketId][_buyer];
        buy.valueEntered = buy.valueEntered.add(_amount);

        Bucket storage bucket = buckets[_bucketId];
        bucket.totalValueEntered = bucket.totalValueEntered.add(_amount);
    }

    event Exited(
        uint256 _bucketId,
        address indexed _buyer,
        uint _tokensExited);
    function exit(uint _bucketId, address _buyer)
        public
    {
        require(
            _bucketId < currentBucket(),
            "can only exit from concluded buckets");

        Buy storage buyToWithdraw = buys[_bucketId][_buyer];
        require(buyToWithdraw.valueEntered > 0, "can't exit if you didn't enter");
        require(buyToWithdraw.buyerTokensExited == 0, "already exited");

        /*
        Note that buyToWithdraw.buyerTokensExited serves a dual purpose:
        First, it is always set to a non-zero value when a buy has been exited from,
        and checked in the line above to guard against repeated exits.
        Second, it's used as simple record-keeping for future analysis;
        hence the use of uint rather than something like bool buyerTokensHaveExited.
        */

        buyToWithdraw.buyerTokensExited = calculateExitableTokens(_bucketId, _buyer);
        totalExitedTokens = totalExitedTokens.add(buyToWithdraw.buyerTokensExited);

        bool transferSuccess = tokenOnSale.mint(_buyer, buyToWithdraw.buyerTokensExited);
        require(transferSuccess, "exit mint/transfer failed");

        emit Exited(
            _bucketId,
            _buyer,
            buyToWithdraw.buyerTokensExited);
    }

    function buyerReferralRewardPerc()
        public
        pure
        returns(uint)
    {
        return ONE_PERC.mul(10);
    }

    function referrerReferralRewardPerc(address _referrerAddress)
        public
        view
        returns(uint)
    {
        if (_referrerAddress == address(0))
        {
            return 0;
        }
        else
        {
            // integer number of dai contributed
            uint daiContributed = referredTotal[_referrerAddress].div(10 ** 18);

            /*
            A more explicit way to do the following 'uint multiplier' line would be something like:

            float bonusFromDaiContributed = daiContributed / 100000.0;
            float multiplier = bonusFromDaiContributed + 0.1;

            However, because we are already using 3 digits of precision for bonus values,
            the integer amount of Dai happens to exactly equal the bonusPercent value we want
            (i.e. 10,000 Dai == 10000 == 10*ONE_PERC)

            So, if multiplier = daiContributed + (10*ONE_PERC), this increases the multiplier
            by 10% for every 10k Dai, which is what we want.
            */
            uint multiplier = daiContributed.add(ONE_PERC.mul(10)); // this guarentees every referrer gets at least 10% of what the buyer is buying

            uint result = Math.min(HUNDRED_PERC, multiplier); // Cap it at 100% bonus
            return result;
        }
    }

    function calculateExitableTokens(uint _bucketId, address _buyer)
        public
        view
        returns(uint)
    {
        Bucket storage bucket = buckets[_bucketId];
        Buy storage buyToWithdraw = buys[_bucketId][_buyer];
        return bucketSupply
            .mul(buyToWithdraw.valueEntered)
            .div(bucket.totalValueEntered);
    }
}