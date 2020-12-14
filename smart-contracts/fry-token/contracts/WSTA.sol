pragma solidity ^0.5.17;

import "../../common.5/openzeppelin/token/ERC20/ERC20Detailed.sol";
import "../../common.5/openzeppelin/token/ERC20/ERC20Mintable.sol";
import "../../common.5/openzeppelin/token/ERC20/ERC20Burnable.sol";
import "../../common.5/openzeppelin/GSN/Context.sol";

contract WSTA is Context, ERC20Detailed, ERC20Mintable, ERC20Burnable
{
    using SafeMath for uint;

    IERC20 public STA;
    
    constructor()
        public
        ERC20Detailed("Wrapper STA", "WSTA", 18)
    { }

    event Wrap(address _wrapper, uint _amountIn, uint _amountWrapped);

    function wrap(uint _amount)
        public
    {
        uint balanceBefore = STA.balanceOf(address(this));
        STA.transferFrom(msg.sender, address(this), _amount);
        uint realAmount = STA.balanceOf(address(this)) - balanceBefore;
        _mint(msg.sender, realAmount);
        emit Wrap(msg.sender, uint _amount, realAmount);
    }

    event Unwrap(address _unwrapper, uint _amountOut, uint _amountUnwrapped);
    function unwrap(uint _amount)
        public
    {
        STA.transfer(address(this), _amount);
        _burn(msg.sender, _amount);
        emit Unwrap(msg.sender, uint _amount, realAmount);
    }
}