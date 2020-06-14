// "SPDX-License-Identifier: UNLICENSED"

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../../common.6/openzeppelin/contracts/math/SafeMath.sol";
import "../../common.6/openzeppelin/contracts/math/Math.sol";

import "./ILiquidDemocracy.sol";
import "./LiquidDemocracyStorage.sol";

abstract contract Governance is ILiquidDemocracy
{
    using SafeMath for uint256;

    DepositStore deposits;
    ProposalStore proposals;
    ProposalVoteStore proposalVotes;
    Proposal[] activeProposals;

    function deposit(uint _tokens, uint _treeDepth)
        external
        override
    {
        // Ensure that the tree depth is not too deep.
        Deposit memory depositRecord = deposits.get(msg.sender);
        // Check that, if there is an existing depositRecord, the tree depth is not changed
        require(depositRecord.treeDepth == 0 || depositRecord.treeDepth == _treeDepth, "incorrect tree depth");
        
        depositRecord.owner = depositRecord.owner == address(0) ? msg.sender : depositRecord.owner;
        depositRecord.treeDepth = _treeDepth;
        depositRecord.ownBalance = depositRecord.ownBalance.add(_tokens);
        depositRecord.votingPower = depositRecord.votingPower.add(_tokens);
        depositRecord.lastRewardClaimDate = Math.max(0, depositRecord.lastRewardClaimDate);
        depositRecord.withdrawalRequestDate = 0;
        deposits.set(msg.sender, depositRecord);

        emit logDeposit(msg.sender, _tokens, _treeDepth);

        if (depositRecord.representative != address(0))
            _delegate(1, depositRecord.owner, depositRecord.representative, _tokens);
    }

    function _delegate(int _sign, address _delegator, address _representative, uint _tokens)
        internal
    {
        require(_sign == -1 || _sign == 1, "not a valid sign");
        Deposit memory repDeposit = deposits.get(_representative);

        repDeposit.votingPower = 
            (_sign == 1) ? 
                repDeposit.votingPower.add(_tokens) : 
                repDeposit.votingPower.sub(_tokens);
        deposits.set(repDeposit.owner, repDeposit);

        emit logDelegation(_delegator, _sign, _tokens, _representative, repDeposit.votingPower);

        if (repDeposit.representative != address(0))
            _delegate(_sign, repDeposit.owner, repDeposit.representative, _tokens);
        else
            _adjustVotes(_sign, repDeposit.owner, _tokens);
    }

    function _adjustVotes(int _sign, address _voter, uint tokens)
        internal
    {
    }
}