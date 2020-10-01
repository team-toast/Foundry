pragma solidity ^0.5.17;

import "../../common.5/openzeppelin/token/ERC20/ERC20Detailed.sol";
import "../../common.5/openzeppelin/token/ERC20/ERC20Mintable.sol";
import "./BucketSale.sol";
import "./Forwarder.sol";

contract PermafrostDeployer
{
    using SafeMath for uint256;

    event Deployed(BucketSale _bucketSale);

    constructor()
        public
    {
        // Create the bucket sale
        BucketSale bucketSale = new BucketSale (
            address(0x01),  // _treasury = 0x01 in case 0x00 is being blocked
            1602504000,     // _startOfSale, Monday, October 12, 2020 12:00:00 PM
            42 hours,     // _bucketPeriod
            225000 * 1e18,  //_bucketSupply
            4,              //_bucketCount
            ERC20Mintable(0x6c972b70c533E2E045F333Ee28b9fFb8D717bE69), // _tokenOnSale = $FRY https://etherscan.io/address/0x6c972b70c533e2e045f333ee28b9ffb8d717be69
            IERC20(0x5277a42ef95ECa7637fFa9E69B65A12A089FE12b)); //_tokenSoldFor = Balancer ETHFRY, 50/50, 10% Fee https://pools.balancer.exchange/#/pool/0x5277a42ef95eca7637ffa9e69b65a12a089fe12b/

        emit Deployed(bucketSale);
    }
}