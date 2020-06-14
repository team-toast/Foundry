// "SPDX-License-Identifier: UNLICENSED"

pragma solidity ^0.6.4;

contract StringStore
{
    mapping (address => mapping (bytes32=>string)) public store;

    function set(bytes32 _key, string memory _value)
        public
    {
        store[msg.sender][_key] = _value;
    }

    function get(bytes32 _key)
        public
        view
        returns (string memory)
    {
        return store[msg.sender][_key];
    }
}

contract UintStore
{
    mapping (address => mapping (bytes32=>uint)) public store;

    function set(bytes32 _key, uint _value)
        public
    {
        store[msg.sender][_key] = _value;
    }

    function get(bytes32 _key)
        public
        view
        returns (uint)
    {
        return store[msg.sender][_key];
    }
}

contract StructStore
{
    mapping (address => mapping(bytes32=>bytes)) public store;

    function set(bytes32 _key, bytes memory _value)
        public
    {
        store[msg.sender][_key] = _value;
    }

    function get(bytes32 _key)
        public
        view
        returns (bytes memory)
    {
        store[msg.sender][_key];
    }
}

contract BoolStore
{
    mapping (address => mapping(bytes32=>bool)) public store;

    function set(bytes32 _key, bool _value)
        public
    {
        store[msg.sender][_key] = _value;
    }

    function get(bytes32 _key)
        public
        view
        returns (bool)
    {
        store[msg.sender][_key];
    }
}

contract Bytes32Store
{
    mapping (address => mapping(bytes32=>bytes32)) public store;

    function set(bytes32 _key, bytes32 _value)
        public
    {
        store[msg.sender][_key] = _value;
    }

    function get(bytes32 _key)
        public
        view
        returns (bytes32)
    {
        store[msg.sender][_key];
    }
}