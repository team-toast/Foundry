// "SPDX-License-Identifier: UNLICENSED"

pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "../../common.6/openzeppelin/contracts/math/SafeMath.sol";
import "../../common.6/openzeppelin/contracts/math/Math.sol";

import "./ILiquidDemocracy.sol";
import "./LiquidDemocracyStorage.sol";

struct LinkedListNode
{
    uint value;
    uint next;
}

abstract contract Governance is ILiquidDemocracy
{
    using SafeMath for uint256;

    DepositStore deposits;
    ProposalStore proposals;
    ProposalVoteStore proposalVotes;
    uint[] activeProposalIds;

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

    function _adjustVotes(int _sign, address _voter, uint _tokens)
        internal
    {
        for (uint i = 0; i < activeProposalIds.length; i++)
        {
            _adjustVote(_sign, _voter, _tokens, activeProposalIds[i]);
        }
    }

    function _adjustVote(int _sign, address _voter, uint _tokens, uint _proposalId)
        internal
    {
        ProposalVote memory proposalVote = proposalVotes.get(_proposalId, _voter);
        if (proposalVote.vote != VoteType.Abstained)
        {
            proposalVote.votingPower = 
                (_sign == 1) ?
                    proposalVote.votingPower.add(_tokens) :
                    proposalVote.votingPower.sub(_tokens);

            proposalVotes.set(_proposalId, _voter, proposalVote);

            Proposal memory proposal = proposals.get(_proposalId);
            if (proposalVote.vote == VoteType.Support)
                proposal.votesInSupport = 
                    (_sign == 1) ?
                        proposal.votesInSupport.add(_tokens) :
                        proposal.votesInSupport.sub(_tokens);
            else if (proposalVote.vote == VoteType.Oppose)
                proposal.votesInOpposition = 
                    (_sign == 1) ?
                        proposal.votesInOpposition.add(_tokens) :
                        proposal.votesInOpposition.sub(_tokens);
            else if (proposalVote.vote == VoteType.OpposeAndBurn)
                proposal.votesToBurn = 
                    (_sign == 1) ?
                        proposal.votesToBurn.add(_tokens) :
                        proposal.votesToBurn.sub(_tokens);
            else
                revert("invalid state reached");

            uint totalVotes = proposal.votesInSupport + proposal.votesInOpposition + proposal.votesToBurn;
            bool thresholdCrossed = proposal.votesInSupport * 1000 / totalVotes > 600;
            if (proposal.acceptedCoolingDown && !thresholdCrossed)
            {
                proposal.acceptedCoolingDown = false;
                proposal.thresholdCrossDate = block.timestamp;
            }
            else if (!proposal.acceptedCoolingDown && thresholdCrossed)
            {
                proposal.acceptedCoolingDown = true;
                proposal.thresholdCrossDate = block.timestamp;
            }
        }
    }
}