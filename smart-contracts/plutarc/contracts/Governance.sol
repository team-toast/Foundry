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
        require(_treeDepth <= 32, "tree depth must be 32 or less");
        Deposit memory depositRecord = deposits.get(msg.sender);
        // If check that, if there is an existing deposit, the tree depth is not changed
        require(depositRecord.treeDepth == 0 || depositRecord.treeDepth == _treeDepth, "incorrect tree depth");
        
        // If there is no existing deposit, register msg.sender, else update the delegation
        if (depositRecord.owner == address(0))
            depositRecord.owner = msg.sender;
        // else
        //     delegate(depositRecord.representative);

        depositRecord.treeDepth = _treeDepth;
        depositRecord.ownBalance = depositRecord.ownBalance.add(_tokens);
        depositRecord.votingPower = depositRecord.votingPower.add(_tokens);
        depositRecord.lastRewardClaimDate = Math.max(0, depositRecord.lastRewardClaimDate);
        depositRecord.withdrawalRequestDate = 0;
        deposits.set(msg.sender, depositRecord);
        emit logDeposit(msg.sender, _tokens, _treeDepth);
    }
}