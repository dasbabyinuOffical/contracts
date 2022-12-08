// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  const feePercent = 3;
  const feeDest = "0xA4F49B1D73d4fF949b6A41bBA301AbdA5640675c";
  const Reward = await hre.ethers.getContractFactory("Reward");
  const reward = await Reward.deploy(feePercent,feeDest);

  await reward.deployed();

  const USDT = await hre.ethers.getContractFactory("USDT")
  const usdt = await USDT.deploy();

  console.log(
    `deployed reward to ${reward.address},deployed usdt to ${usdt.address}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
