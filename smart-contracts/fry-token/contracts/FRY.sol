pragma solidity ^0.5.17;

import "../../common.5/openzeppelin/token/ERC20/ERC20Detailed.sol";
import "../../common.5/openzeppelin/token/ERC20/ERC20Mintable.sol";
import "../../common.5/openzeppelin/token/ERC20/ERC20Burnable.sol";
import "../../common.5/openzeppelin/GSN/Context.sol";

contract FRY is Context, ERC20Detailed, ERC20Mintable, ERC20Burnable
{
    using SafeMath for uint;

    constructor()
        public
        ERC20Detailed("Foundry Logistics Token", "FRY", 18)
    { }
}