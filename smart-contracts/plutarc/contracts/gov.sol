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
    uint proposalId;
    address voter;
    uint votes;
    bool inFavour;
    bool opposed;
    bool burn;
}

struct DepositRecord
{
    address owner;
    uint treeDepth;
    address representative;
    
    uint ownBalance;
    uint delegatedBalance;
    uint votingPower;

    uint lastInterestClaimDate;
    
    uint withdrawalRequestDate;
}

interface ILiquidDemocracy // ironic name
{
    // deposits and delegates, _treeDepth indicates the treedepth any representative must be less than to delegate to
    function Deposit(uint _tokens, uint _treeDepth, address _representative) external;

    // delegates tokens already deposited to a new represetative
    function Delegate(address _representative) external;

    // dedelgate that number of tokens and start the withdrawal times
    function ScheduleWithdrawal(uint _tokens) external;

    // once the withdrawal timer has cooled down, execute the withdrawal
    function ExecuteWithdrawal() external;

    // propose an action for the governance contract to take, sending a predetermined amount of tokens to the treasury
    function Propose(uint _proposalId, bool _isDelegateCall, address _to, uint _wei, bytes calldata _data) external;

    // vote for a proposal if you have deposited tokens and not delegated them
    function Vote(uint _proposalId, bool supportOrOppose) external;

    // execute a successful proposal
    function Execute(uint _proposalId) external;

    // remove an unsuccessful proposal
    function RemoveProposal(uint _proposalId) external;
}