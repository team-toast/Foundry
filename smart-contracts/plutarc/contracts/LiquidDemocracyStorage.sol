// "SPDX-License-Identifier: UNLICENSED"

pragma solidity ^0.6.4;
pragma experimental ABIEncoderV2;

import "./ILiquidDemocracy.sol";

contract DepositStore
{
    mapping (address => mapping (address => Deposit)) public store;

    function set(address _key, Deposit memory _value)
        public
    {
        store[msg.sender][_key] = _value;
    }

    function get(address _key)
        public
        view
        returns (Deposit memory)
    {
        return store[msg.sender][_key];
    }
}

contract ProposalStore
{
    mapping (address => mapping (uint => Proposal)) public store;

    function set(uint _key, Proposal memory _value)
        public
    {
        store[msg.sender][_key] = _value;
    }

    function get(uint _key)
        public
        view
        returns (Proposal memory)
    {
        return store[msg.sender][_key];
    }
}

contract ProposalVoteStore
{
    mapping (address => mapping (bytes32 => ProposalVote)) public store;

    function set(bytes32 _key, ProposalVote memory _value)
        public
    {
        store[msg.sender][_key] = _value;
    }

    function get(bytes32 _key)
        public
        view
        returns (ProposalVote memory)
    {
        return store[msg.sender][_key];
    }
}