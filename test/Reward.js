const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");

describe("Reward", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployRewardFixture() {
    const feePercent = 3;
    const feeDest = "0xA4F49B1D73d4fF949b6A41bBA301AbdA5640675c";

    // Contracts are deployed using the first signer/account by default
    const [owner] = await ethers.getSigners();
    const Reward = await ethers.getContractFactory("Reward");
    const reward = await Reward.deploy(feePercent,feeDest);

    const USDT = await ethers.getContractFactory("USDT")
    const usdt = await USDT.deploy();

    return {reward,owner,feePercent,feeDest,usdt};
  }
  describe("Deployment", function () {
    it("Should set the right fee", async function () {
      const {reward,feePercent} = await loadFixture(deployRewardFixture);

      expect(await reward.fee()).to.equal(feePercent);
    });

    it("Should set the right feeDest", async function () {
      const {reward,feeDest} = await loadFixture(deployRewardFixture);

      expect(await reward.feeAddress()).to.equal(feeDest);
    });
  });

  describe("Deposit",function(){
    it("CreatePool",async function(){
      const {reward,owner,usdt} = await loadFixture(deployRewardFixture);
      const block = (await ethers.provider.getBlock("latest"))
      const supply = await usdt.totalSupply();
      const startBlock = ethers.BigNumber.from(block.number);
      const endBlock = ethers.BigNumber.from(block.number+1000);

      const balance = await usdt.balanceOf(owner.address);
      expect(balance).to.equal(supply);

      // approve
      await usdt.approve(reward.address,supply);
      console.log("owner is:",owner.address,balance);

      await reward.createPool(usdt.address,usdt.address,supply,startBlock,endBlock);
      expect(await reward.poolId()).to.equal(ethers.BigNumber.from(1));
    });
  });

});