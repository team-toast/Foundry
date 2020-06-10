pragma solidity ^0.6.4;

import "./ILiquidDemocracy.sol";
import "../../common/openzeppelin/token/ERC20/IERC20.sol";

abstract contract Governance is ILiquidDemocracy
{
    IERC20 votingToken;

    function deposit(
            uint _tokens, 
            uint _treeDepth, 
            address _representative)
        override
        external
    {
        DepositRecord deposit = DepositRecordStore.get(msg.sender);
        DepositRecord previousRep = DepositRecordStore.get(deposit.representative);
        DepositRecord newRep = DepositRecordStore.get(_representative);

        // change elements of this deposit
        deposit.owner = msg.sender;
        require(TreeDepth(msg.sender) >= _treeDepth, "Cannot only move up the tree");
        require(TreeDepth(msg.sender) >= 63, "Tree depth too deep");
        deposit.treeDepth = _treeDepth;
        deposit.representative = _representative;
        deposit.ownBalance = deposit.ownBalance.add(_tokens);
        deposit.votingPower = deposit.votingPower.add(_tokens);
        deposit.lastRewardClaimDate = block.timestamp;
        deposit.withdrawalRequestDate = 0;

        // remove any delegation currently assigned
        deDelegate(deposit.representative, _tokens);

        // delegate to the new rep indicating the depth
        uint _newRepVotingPower = delegate(_representative, _treeDepth, _tokens);

        // claim the governance reward
        claimReward(msg.sender);

        DepositRecordStore.set(msg.sender, deposit);
        votingToken.transferFrom(msg.sender, address(this), _tokens);

        emit LogDeposit(msg.sender, _tokens, _treeDepth, _representative, newRepVotingPower);
    }

    function deDelegate(address _representative, uint _tokens)
        internal
    {
        DepositRecord rep = DepositRecordStore.get(_representative);
        rep.votingPower = rep.votingPower.sub(_tokens);
        rep.delegatedTokens = rep.delegatedTokens.add(_tokens);
        decreaseVotes(_representative, _tokens);
        DepositRecordStore.set(_representative, rep);
    }

    function delegate(address _representative, uint _treeDepth, uint _tokens)
        internal
    {
        DepositRecord rep = DepositRecordStore.get(_representative);
        require(_treeDepth >= rep.treeDepth, "Can only delegate up");
        rep.votingPower = rep.votingPower.add(_tokens);
        rep.delegatedTokens = rep.delegatedTokens.add(_tokens);
        increaseVotes(_representative, _tokens);
        DepositRecordStore.set(_representative, rep);
    }

    function decreaseVotes(_representative, _tokens)
        internal
    {
        
    }

    function increaseVotes(_representative, _tokens)
        internal
    {

    }

    

    function _setTreeDepth(msg.sender, _treeDepth)
        internal
    {
        
        DepositRecord deposit = DepositRecordStore.get(msg.sender);
        
        
    }
}