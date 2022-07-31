const hre = require("hardhat");
const { ethers } = require("hardhat");

async function main() {
  const [owner, addr1] = await ethers.getSigners();
  const Payment = await hre.ethers.getContractFactory("Payment");
  const payment = await Payment.deploy(
    "0x5FbDB2315678afecb367f032d93F642f64180aa3",
    "0x5FbDB2315678afecb367f032d93F642f64180aa3"
  );

  await payment.deployed();
  console.log("Payment has been deployed to:", payment.address);
  const ExpanderSubscriptions = await hre.ethers.getContractFactory(
    "ExpanderSubscriptions"
  );

  const expanderSubscriptions = await ExpanderSubscriptions.deploy(
    "1",
    "Ethereum",
    addr1.address
  );

  await expanderSubscriptions.deployed();

  console.log(
    "ExpanderSubscriptions has been deployed to:",
    expanderSubscriptions.address
  );
  const WETH = await hre.ethers.getContractFactory("WETH");
  const weth = await WETH.deploy(
    ethers.utils.parseUnits(String(21 * 10 ** 9), 18)
  );
  await weth.deployed();
  console.log("WETH has been deployed to:", weth.address);

  const ExpanderCreatorFactory = await hre.ethers.getContractFactory(
    "ExpanderCreatorFactory"
  );
  const expanderCreatorFactory = await ExpanderCreatorFactory.deploy(
    addr1.address
  );
  await expanderCreatorFactory.deployed();

  console.log(
    "ExpanderCreatorFactory has been deployed to:",
    expanderCreatorFactory.address
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
