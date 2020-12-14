pragma solidity ^0.5.17;

import "../../common.5/openzeppelin/token/ERC20/ERC20Detailed.sol";
import "../../common.5/openzeppelin/token/ERC20/ERC20Mintable.sol";
import "../../common.5/openzeppelin/token/ERC20/ERC20Burnable.sol";
import "../../common.5/openzeppelin/GSN/Context.sol";

contract WSTA is Context, ERC20Detailed, ERC20Mintable, ERC20Burnable
{
    using SafeMath for uint;

    ERC20Mintable public STA;
    
    constructor()
        public
        ERC20Detailed("Wrapper STA", "WSTA", 18)
    { 
        STA = ERC20Mintable(0xa7DE087329BFcda5639247F96140f9DAbe3DeED1);
    }

    event Wrap(address _wrapper, uint _amountIn, uint _amountWrapped);
    function wrap(uint _amount)
        public
    {
        uint balanceBefore = STA.balanceOf(address(this));
        STA.transferFrom(msg.sender, address(this), _amount);
        uint realAmount = STA.balanceOf(address(this)).sub(balanceBefore);
        _mint(msg.sender, realAmount);
        emit Wrap(msg.sender, _amount, realAmount);
    }

    event Unwrap(address _unwrapper, uint _amountUnwrapped, uint _amountOut);
    function unwrap(uint _amount)
        public
    {
        uint balanceBefore = STA.balanceOf(address(this));
        STA.transfer(address(this), _amount);
        uint realAmount = STA.balanceOf(address(this)).sub(balanceBefore);
        _burn(msg.sender, _amount);
        emit Unwrap(msg.sender, _amount, realAmount);
    }
}