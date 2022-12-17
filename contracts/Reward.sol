// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Reward is ReentrancyGuard{
    struct Pool{
        uint256 poolId;
        address owner;
        IERC20Metadata  depositToken;
        IERC20Metadata  rewardToken;
        uint8   depositTokenDecimal;
        uint256 supply;
        uint256 depositAmount;
        uint256 startBlock;
        uint256 endBlock;
    }
    
    struct User{
        address user;
        IERC20Metadata  token;
        uint256 amount;
        uint256 depositBlock;
    }

    uint256 public poolId;
    uint256 public fee = 3;
    address public feeAddress;
    mapping(uint256 => Pool) public pools;
    mapping(address => mapping(uint256 =>User)) public  users;

    constructor(uint256 feePercent,address feeDest){
        fee = feePercent;
        feeAddress =  feeDest;
    }

    function createPool(IERC20Metadata depositToken,IERC20Metadata rewardToken,uint256 supply,uint256 endBlock) external nonReentrant {
        require(endBlock > block.number,"end block must bigger than start block");
        poolId ++;

        uint256 balanceBefore = rewardToken.balanceOf(address(this));
        rewardToken.transferFrom(msg.sender,address(this), supply);
        uint256 balanceAfter = rewardToken.balanceOf(address(this));
        if(balanceAfter-balanceBefore < supply){
            supply = balanceAfter - balanceBefore;
        }

        pools[poolId].poolId = poolId;
        pools[poolId].owner = msg.sender;
        pools[poolId].depositToken = depositToken;
        pools[poolId].rewardToken = rewardToken;
        pools[poolId].depositTokenDecimal = depositToken.decimals();
        pools[poolId].supply = supply;
        pools[poolId].startBlock = block.number;
        pools[poolId].endBlock = endBlock;
    }

    function deposit(uint256 depositPoolId,IERC20Metadata token, uint256 amount) external nonReentrant {
        Pool memory pool =  pools[depositPoolId];
        require(pool.endBlock >= block.number  && pool.startBlock <= block.number,"pool not exist or already end");
        require(address(pool.depositToken) == address(token),"not support token");
        
        uint256 balanceBefore = token.balanceOf(address(this));
        token.transferFrom(msg.sender,address(this), amount);
        uint256 balanceAfter = token.balanceOf(address(this));

        if(balanceAfter-balanceBefore < amount){
            amount = balanceAfter - balanceBefore;
        }

        pools[depositPoolId].depositAmount += amount;

        claimRewards(depositPoolId);

        User memory user = users[msg.sender][depositPoolId];
        user.token = token;
        user.amount += amount;
        user.user = msg.sender;
        user.depositBlock = block.number;
        users[msg.sender][depositPoolId]  = user;
    }

    function claimRewards(uint256 claimPoolId) public{
        uint256 reward = rewards(claimPoolId,msg.sender);
        if (reward == 0){
            return;
        }

        uint256 endBlock = block.number;
        Pool memory pool = pools[claimPoolId];
        if (endBlock > pool.endBlock){
            endBlock = pool.endBlock;
        }
        users[msg.sender][claimPoolId].depositBlock = endBlock;

        IERC20Metadata token = pool.rewardToken;
        
        pools[claimPoolId].supply -= reward;
        uint256 userReward = reward*(100-fee)/100;
        uint256 rewardFee = reward - userReward;
        if (userReward > 0 ){
            token.transfer(msg.sender, userReward);
        }
        if (rewardFee > 0){
            token.transfer(feeAddress, rewardFee);
        }
    }

    function withdraw(uint256 withdrawPoolId,bool isEmergecy) internal{
        claimRewards(withdrawPoolId);
        Pool memory pool = pools[withdrawPoolId];
        IERC20Metadata token = pool.depositToken;
        uint256 balance = users[msg.sender][withdrawPoolId].amount;
        if (balance == 0 || pool.depositAmount < balance){
            return;
        }

        pools[withdrawPoolId].depositAmount -= balance;
        
        if (!isEmergecy){
            users[msg.sender][withdrawPoolId].amount = 0;
            token.transfer(msg.sender,balance);
            return;
        }

        uint256 userBalance = (100-fee)*balance/100;
        uint256 feeBalance = balance - userBalance;
        users[msg.sender][withdrawPoolId].amount = 0;
        if (userBalance > 0 ){
            token.transfer(msg.sender,userBalance);
        }
        if (feeBalance > 0){
            token.transfer(feeAddress,feeBalance);
        } 
    }

    function rewards(uint256 pid,address sender) public view returns (uint256 userReward){
        Pool memory pool = pools[pid];

        if (pool.endBlock == 0 || pool.depositAmount == 0){
            return 0;
        }

        uint256 endBlock = block.number;
        if (endBlock > pool.endBlock){
            endBlock = pool.endBlock;
        }

        uint256 blockDelta  = endBlock - pool.startBlock;
        
        User memory user = users[sender][pid];
        userReward = user.amount*pool.supply/pool.depositAmount*blockDelta/(pool.endBlock - pool.startBlock);
    }

    function  withdrawAll(uint256 withdrawPoolId) external nonReentrant {
        Pool memory pool = pools[withdrawPoolId];
        require(block.number > pool.endBlock && pool.endBlock > 0,"pool not end yet");
        withdraw(withdrawPoolId,false);
    }

    function emergencyWithdrawAll(uint256 withdrawPoolId) external nonReentrant {
        Pool memory pool = pools[withdrawPoolId];
        require(block.number > pool.startBlock && pool.startBlock > 0,"pool not start yet");
        withdraw(withdrawPoolId,true);
    }
}