import { ethers } from "hardhat";

async function main() {

  const Vesting = await ethers.getContractFactory("DAOTreasuryVesting");
  const vesting = await Vesting.deploy("0x0d3478ff714cc01242a13db1C0581DCCe199559A");

  await vesting.deployed();

  console.log(
    `Vesting contract deployed at ${vesting.address}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

