// "SPDX-License-Identifier: UNLICENSED"

pragma solidity ^0.6.4;

// general notes:
// * this contract should own a forwarder
// * should there be a withdrawal time delay? yes
// * should there be "voting rewards"? yes
// * proposals that succeed or fail outright, as opposed to succeeding or failing after timeout, should yield a
// * higher reward because they represent an active interest in the vote.
// * should there be a veto key list? a set of users who may stop a vote.

struct Deposit
{
    address owner;      // key
    uint treeDepth;
    address representative;
    
    uint ownBalance;
    uint delegatedBalance;
    uint votingPower;

    uint lastRewardClaimDate;
    
    uint withdrawalRequestDate;
}

struct Proposal
{
    uint id;            // key

    address bondReturnAddress;
    uint bondAmount;
    uint votesInSupport;
    uint votesInOpposition;
    uint votesToBurn;
    bool acceptedCoolingDown;
    uint thresholdCrossDate;

    bool isDelegateCall;
    address to;
    uint weiAmount;
    bytes data;
}

struct ProposalVote
{
    uint proposalId;    // key
    address voter;      // key
    uint votingPower;
    VoteType vote;
}

enum DelegationType 
{ 
    Delegate,
    Dedelegate 
}

enum VoteType 
{
    Abstained,
    Support,
    Oppose,
    OpposeAndBurn
}

interface ILiquidDemocracy // ironic name
{
    // deposits and delegates, _treeDepth indicates the treedepth any representative must be less than to delegate to
    function deposit(uint _tokens, uint _treeDepth) external;
    event logDeposit(address indexed _depositor, uint _tokens, uint _treeDepth);

    // delegates tokens already deposited to a new represetative
    function delegate(address _representative) external;
    event logDelegation(address indexed _depositor, int _sign, uint _tokens, address indexed _representative, uint _representativeVotingPower);

    // deposits and delegates, _treeDepth indicates the treedepth any representative must be less than to delegate to
    function depositAndDelegate(uint _tokens, uint _treeDepth, address _representative) external;

    // change you tree depth if no one on a lower depth is not already delegating to you 
    // and you aren't delegating to anyone on a higher depth
    function changeTreeDepth(uint _newDepth) external;
    event logTreeDepthChanged(address indexed _depositor, uint _tokens, uint _treeDepth);

    // claim spendable governance rewards based on when last you pulled rewards 
    function claimReward(address _depositAddress) external;
    event logRewardClaimed(address _depositAddress, uint _rewardTokens);

    // dedelgate that number of tokens and start the withdrawal times
    function scheduleWithdrawal(uint _tokens) external;
    event logWithdrawalRequested(address indexed _depositor, uint _tokens, uint _treeDepth, address indexed _representative);

    // once the withdrawal timer has cooled down, execute the withdrawal
    function executeWithdrawal() external;
    event logWithdrawalExecuted(address indexed _depositor, uint _tokens);

    // propose an action for the governance contract to take, sending a predetermined amount of tokens to the treasury
    function propose(uint _proposalId, bool _isDelegateCall, address _to, uint _wei, bytes calldata _data) external;
    event LogProposalCreated(uint _proposalId, bool _isDelegateCall, address _to, uint _wei);

    // vote for a proposal if you have deposited tokens and not delegated them
    function vote(uint _proposalId, bool supportOrOppose) external;
    event logVoted(address indexed _voter, uint _votingPower, uint _proposalId, VoteType _voteType);

    // execute a successful proposal
    function execute(uint _proposalId) external;
    event logProposalExecuted(uint _proposalId, bool _wasDelegateCall, bool _wasSuccessful);
    event logBondReturned(uint _proposalId, address _bondReturnAddress, uint _tokens);

    // remove an unsuccessful proposal
    function removeProposal(uint _proposalId) external;
    event logProposalRemoved(uint _proposalId);
    event logBondBurned(uint _proposalId, address _bondReturnAddress, uint _tokens);
}