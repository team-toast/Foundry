// "SPDX-License-Identifier: UNLICENSED"

pragma solidity ^0.6.4;

contract Proxy
{
    address public implementation;

    constructor (address _implementation)
        public
    {
        implementation = _implementation;
    }

    event logImplementationChanged(address _newImplementation);
    function changeImplemenation(address _newImplementation)
        public
    {
        require(msg.sender == address(this), "all true change must come from within");
        implementation = _newImplementation;
        emit logImplementationChanged(_newImplementation);
    }

    receive()
        external
        payable
    {}

    fallback()
        external
        payable
    {
        assembly
        {
            let _delegate := sload(0)
            calldatacopy(0x0, 0x0, calldatasize())
            let result := delegatecall(gas(), _delegate, 0x0, calldatasize(), 0x0, 0)
            switch result
                case 0
                {
                    revert(0,0)
                }
                default
                {
                    return(0,returndatasize())
                }
        }
    }
}