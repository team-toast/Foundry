pragma solidity ^0.6.0;

import "./ILiquidDemocracy.sol";
import "../../common.6/openzeppelin/contracts/math/SafeMath.sol";
import "../../common.6/openzeppelin/contracts/math/Math.sol";

abstract contract Governance is ILiquidDemocracy
{
    using SafeMath for uint256;

    function deposit(uint _tokens, uint _treeDepth)
        external
        override
    {
        // Ensure that the tree depth is not too deep.
        require(_treeDepth <= 32, "tree depth must be 32 or less");
        DepositRecord deposit = deposits.get(msg.sender);
        // If check that, if there is an existing deposit, the tree depth is not changed
        require(deposit.treeDepth == 0 || deposit.treeDepth == _treeDepth, "incorrect tree depth");
        
        // If there is no existing deposit, register msg.sender, else update the delegation
        if (deposit.owner == address(0))
            deposit.owner = msg.sender;
        else
            delegate(deposit.representative);

        deposit.treeDepth = _treeDepth;
        deposit.ownBalance = deposit.ownBalance.add(_tokens);
        deposit.votingPower = deposit.votingPower.add(_tokens);
        deposit.lastRewardClaimDate = Math.max(0, deposit.lastRewardClaimDate);
        deposit.withdrawalRequestDate = 0;
        deposits.set(msg.sender, deposit);
        emit logDeposit(msg.sender, _tokens, _treeDepth);
    }
}