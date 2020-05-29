pragma solidity ^0.5.0;

import "./openzeppelin/token/ERC20/ERC20Detailed.sol";
import "./openzeppelin/token/ERC20/ERC20Mintable.sol";
import "./openzeppelin/token/ERC20/ERC20Burnable.sol";
import "./openzeppelin/GSN/Context.sol";

contract FakeDAI is Context, ERC20Detailed, ERC20Mintable, ERC20Burnable
{
    using SafeMath for uint;

    constructor(
            address _recipient)
        public
        ERC20Detailed("Fake DAI", "FAI", 18)
    {
        _mint(_recipient, uint(100000000).mul(10 ** uint256(decimals())));
    }
}