pragma solidity ^0.5.17;

import "../../common.5/DebugBase.sol";

import "../../common.5/openzeppelin/token/ERC20/ERC20Detailed.sol";
import "../../common.5/openzeppelin/token/ERC20/ERC20Mintable.sol";
import "../../common.5/openzeppelin/token/ERC20/ERC20Burnable.sol";
import "../../common.5/openzeppelin/GSN/Context.sol";

contract TestToken is Context, ERC20Detailed, ERC20Mintable, ERC20Burnable
{
    using SafeMath for uint;

    constructor(
            string memory _tokenName,
            string memory _tokenCode,
            address _tokenReceiver,
            uint _amount)
        public
        ERC20Detailed(_tokenName, _tokenCode, 18)
    {
        _mint(_tokenReceiver, _amount.mul(10 ** uint256(decimals())));
    }
}

contract Debug is DebugBase { }