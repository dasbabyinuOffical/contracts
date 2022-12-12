// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

contract Reward{
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
        uint256 rewardShare;
        uint256 rewardPerBlock;
        uint256 lastUpdateBlock;
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

    function createPool(IERC20Metadata depositToken,IERC20Metadata rewardToken,uint256 supply,uint256 endBlock) external{
        require(endBlock > block.number,"end block must bigger than start block");
        poolId ++;
        pools[poolId].poolId = poolId;
        pools[poolId].owner = msg.sender;
        pools[poolId].depositToken = depositToken;
        pools[poolId].rewardToken = rewardToken;
        pools[poolId].depositTokenDecimal = depositToken.decimals();
        pools[poolId].supply = supply;
        pools[poolId].startBlock = block.number;
        pools[poolId].lastUpdateBlock = block.number;
        pools[poolId].endBlock = endBlock;
        pools[poolId].rewardPerBlock = supply/(endBlock-block.number);

        rewardToken.transferFrom(msg.sender,address(this), supply);
    }

    function deposit(uint256 depositPoolId,IERC20Metadata token, uint256 amount) external{
        Pool memory pool =  pools[poolId];
        require(pool.endBlock >= block.number  && pool.startBlock <= block.number,"pool not exist or already end");
        require(address(pool.depositToken) == address(token),"not support token");
        pools[poolId].depositAmount += amount;

        claimRewards(depositPoolId);

        User memory user = users[msg.sender][depositPoolId];
        user.token = token;
        user.amount += amount;
        user.user = msg.sender;
        user.depositBlock = block.number;
        users[msg.sender][poolId]  = user;
        
        token.transferFrom(msg.sender,address(this), amount);
    }

    function claimRewards(uint256 claimPoolId) public{
        updateReward(claimPoolId);
        uint256 reward = rewards(claimPoolId);
        if (reward == 0){
            return;
        }

        IERC20Metadata token = pools[claimPoolId].rewardToken;
        
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

    function rewards(uint256 pid) public view returns (uint256 userReward){
        Pool memory pool = pools[pid];

        if (block.number <= pool.lastUpdateBlock || pool.endBlock == 0 || pool.depositAmount == 0){
            return 0;
        }

        uint256 endBlock = block.number;
        if (endBlock > pool.endBlock){
            endBlock = pool.endBlock;
        }

        uint256 blockDelta  = endBlock - pool.lastUpdateBlock;
        uint256 rewardShare = pool.rewardShare + blockDelta*pool.rewardPerBlock*(10**pool.depositTokenDecimal)/pool.depositAmount;
        
        User memory user = users[msg.sender][pid];
        userReward = user.amount*(endBlock-user.depositBlock)*rewardShare /(endBlock - pool.startBlock)/(10**pool.depositTokenDecimal);
    }

    function updateReward(uint256 pid) internal{
        Pool memory pool = pools[pid];

        if (block.number <= pool.lastUpdateBlock || pool.lastUpdateBlock == 0 || pool.depositAmount == 0){
            return;
        }

        uint256 endBlock = block.number;
        if (endBlock > pool.endBlock){
            endBlock = pool.endBlock;
        }

        uint256 blockDelta  = endBlock - pool.lastUpdateBlock;
        pool.rewardShare += blockDelta*pool.rewardPerBlock*(10**pool.depositTokenDecimal)/pool.depositAmount;
        pool.lastUpdateBlock = endBlock;

        pools[pid] = pool;
    }

    function  withdrawAll(uint256 withdrawPoolId) external{
        Pool memory pool = pools[withdrawPoolId];
        require(block.number > pool.endBlock && pool.endBlock > 0,"pool not end yet");
        withdraw(poolId,false);
    }

    function emergencyWithdrawAll(uint256 withdrawPoolId) external{
        Pool memory pool = pools[withdrawPoolId];
        require(block.number > pool.startBlock && pool.startBlock > 0,"pool not start yet");
        withdraw(poolId,true);
    }

}