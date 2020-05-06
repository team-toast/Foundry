pragma solidity ^0.5.0;

import {FRY as FRY} from "../../fry-token/contracts/FRY.sol";
import "./BucketSale.sol";
import "./Forwarder.sol";


contract MrMeseeks
{
    using SafeMath for uint256;

    constructor(
            address _teamToastMultisig,
            uint _startOfSale,
            uint _bucketPeriod,
            uint _bucketSupply,
            uint _bucketCount,
            IERC20 _tokenSoldFor
            )
        public
    {
        // Create the treasury contract, giving initial ownership to the Team Toast multisig
        Forwarder governanceTreasury = new Forwarder(_teamToastMultisig);

        // Create the FRY token
        FRY fryToken = new FRY();

        // Create the bucket sale
        BucketSale bucketSale = new BucketSale (
            address(governanceTreasury),
            _startOfSale,
            _bucketPeriod,
            _bucketSupply,
            _bucketCount,
            ERC20Mintable(address(fryToken)),
            _tokenSoldFor);

        // 30% disbursed to Team Toast
        fryToken.mint(_teamToastMultisig, uint(30000000).mul(10 ** uint256(fryToken.decimals())));

        // 10% given to the governance treasury
        fryToken.mint(address(governanceTreasury), uint(10000000).mul(10 ** uint256(fryToken.decimals())));

        // Team Toast will have minting rights via a multisig, to be renounced as various Foundry contracts prove stable and self-organizing
        fryToken.addMinter(_teamToastMultisig);

        // Give the bucket sale minting rights
        fryToken.addMinter(address(bucketSale));

        // Have this contract renounce minting rights
        fryToken.renounceMinter();

        // Meseeks
        selfdestruct(msg.sender);
    }
}