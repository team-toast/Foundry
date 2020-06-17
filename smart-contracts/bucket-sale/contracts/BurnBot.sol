pragma solidity ^0.5.17;

import "../../common.5/openzeppelin/token/ERC20/IERC20.sol";
import "../../common.5/openzeppelin/token/ERC20/ERC20Burnable.sol";

contract BurnBot
{
    function burnTotalBalance(ERC20Burnable erc20)
        public
    {
        uint balance = erc20.balanceOf(address(this));
        erc20.burn(balance);
    }
}