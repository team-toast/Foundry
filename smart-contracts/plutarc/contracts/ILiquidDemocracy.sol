pragma solidity ^0.6.4;

// general notes:
// * this contract should own a forwarder
// * should there be a withdrawal time delay? yes
// * should there be "voting rewards"? yes
// * proposals that succeed or fail outright, as opposed to succeeding or failing after timeout, should yield a
// * higher reward because they represent an active interest in the vote.
// * should there be a veto key list? a set of users who may stop a vote.

struct Proposal
{
    uint id;

    address bondReturnAddress;
    uint bondAmount;
    uint votesInFavour;
    uint votesOpposed;
    uint votesToBurn;
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

struct DepositRecord
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

enum VoteType { Support, Oppose, OpposeAndBurn }

interface ILiquidDemocracy // ironic name
{
    // deposits and delegates, _treeDepth indicates the treedepth any representative must be less than to delegate to
    function Deposit(uint _tokens, uint _treeDepth, address _representative) external;
    event LogDeposit(address indexed _depositor, uint _tokens, uint _treeDepth, address indexed _representative, uint _representativeVotingPower);

    // delegates tokens already deposited to a new represetative
    function Delegate(address _representative) external;
    event LogDelegation(address indexed _depositor, uint _tokens, uint _treeDepth, address indexed _representative, uint _representativeVotingPower);

    // change you tree depth if no one on a higher depth is not already delegating to you 
    // and you aren't delegating to anyone on a lower depth
    function ChangeTreeDepth(uint _newDepth) external;
    event LogTreeDepthChanged(address indexed _depositor, uint _tokens, uint _treeDepth);

    // claim spendable governance rewards based on when last you pulled rewards 
    function ClaimReward(address _depositAddress) external;
    event LogRewardClaimed(address _depositAddress, uint _rewardTokens);

    // dedelgate that number of tokens and start the withdrawal times
    function ScheduleWithdrawal(uint _tokens) external;
    event LogWithdrawalRequested(address indexed _depositor, uint _tokens, uint _treeDepth, address indexed _representative);

    // once the withdrawal timer has cooled down, execute the withdrawal
    function ExecuteWithdrawal() external;
    event LogWithdrawalExecuted(address indexed _depositor, uint _tokens);

    // propose an action for the governance contract to take, sending a predetermined amount of tokens to the treasury
    function Propose(uint _proposalId, bool _isDelegateCall, address _to, uint _wei, bytes calldata _data) external;
    event LogProposalCreated(uint _proposalId, bool _isDelegateCall, address _to, uint _wei);

    // vote for a proposal if you have deposited tokens and not delegated them
    function Vote(uint _proposalId, bool supportOrOppose) external;
    event LogVoted(address indexed _voter, uint _votingPower, uint _proposalId, VoteType _voteType);

    // execute a successful proposal
    function Execute(uint _proposalId) external;
    event LogProposalExecuted(uint _proposalId, bool _wasDelegateCall, bool _wasSuccessful);
    event LogBondReturned(uint _proposalId, address _bondReturnAddress, uint _tokens);

    // remove an unsuccessful proposal
    function RemoveProposal(uint _proposalId) external;
    event LogProposalRemoved(uint _proposalId);
    event LogBondBurned(uint _proposalId, address _bondReturnAddress, uint _tokens);
}