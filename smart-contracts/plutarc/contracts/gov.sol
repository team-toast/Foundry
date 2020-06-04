pragma solidiy ^0.5.17;

// general notes:
// * this contract should own a forwarder
// * should there be a withdrawal time delay?
// * should there be "voting rewards"? 
// * should there be "delegation rewards"?
// * rewards could be purely time based, but pay out every time you take an action, IE to vote or even change a vote
//   paying out the amount due since the previous action was taken. 
// * rewards could have 2 tiers, one for delegation and a higher one for actual voting
// * there needs to be a burn of some sort when submitting proposals
//      * 1/10^6th of the total supply? 
//      * maybe it needn't burn the funds, maybe it can simply go to the treasury contract
// * proposals that succeed or fail outright, as opposed to succeeding or failing after timeout, should yield a 
//   higher reward because they represent an active interest in the vote.
// * should there be a veto key list? a set of users who may stop a vote. 

interface ILiquidDemocracy // ironic name
{
    // deposits and delegates
    function Deposit(uint _tokens, address _representative) external;

    // delegates tokens already deposited to a new represetative
    function Delegate(address _representative) external;

    // dedelgate that number of tokens and start the withdrawal times
    function ScheduleWithdrawal(uint _tokens) external;

    // once the with drawal timer has cooled down, execute the withdrawal
    function ExecuteWithdrawal() external;

    // propose an action for the governance contract to take, sending a predetermined amount of tokens to the treasury
    function Propose(uint _proposalId, address _to, bytes calldata _data, uint _wei) external;

    // vote for a proposal if you have deposited tokens and not delegated them
    function Vote(uint _proposalId, bool supportOrOppose) external;

    // execute a successful proposal
    function Execute(uint _proposalId) external;
}