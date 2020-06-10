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

contract UseStorage
{
    StringStore public stringStore;
    UintStore public uintStore;

    // variables
    bytes32 public name = "name";

    constructor (string memory _name)
        public
    {
        // simplistic use
        stringStore.set(name, _name);
    }

    function add(address _owner, int _add)
        public
        returns (uint _supply)
    {
        // starts to get a little cumbersome, but entirely managable
        _supply = uint(int(balance(_owner)) + _add);
        setBalance(_owner, _supply);
    }

    // equivalent to:
    // mapping (address => uint) public balances;
    bytes32 public __balances = "balances";
    function balance(address _owner)
        public
        view
        returns (uint)
    {
        return uintStore.get(keccak256(abi.encode(__balances,_owner)));
    }
    function setBalance(address _owner, uint _balance)
        private
    {
        uintStore.set(keccak256(abi.encode(__balances,_owner)), _balance);
    }
}
