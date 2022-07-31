const hre = require("hardhat");
const { ethers } = require("hardhat");

async function main() {
  const gatewayContract = "0xC249632c2D40b9001FE907806902f63038B737Ab";
  const gasContract = "0xbE406F0189A0B4cf3A05C286473D23791Dd44Cc6";
  const [owner] = await ethers.getSigners();
  console.log("Deployer address is: ", owner.address);
  const Payment = await hre.ethers.getContractFactory("Payment");
  const payment = await Payment.deploy(gatewayContract, gasContract);
  await payment.deployed();
  console.log("Payment has been deployed to:", payment.address);
  return;
  const ExpanderSubscriptions = await hre.ethers.getContractFactory(
    "ExpanderSubscriptions"
  );

  const expanderSubscriptions = await ExpanderSubscriptions.deploy(
    "43113",
    "Avalanche",
    owner.address
  );

  await expanderSubscriptions.deployed();

  console.log(
    "ExpanderSubscriptions has been deployed to:",
    expanderSubscriptions.address
  );

  const ExpanderCreatorFactory = await hre.ethers.getContractFactory(
    "ExpanderCreatorFactory"
  );
  const expanderCreatorFactory = await ExpanderCreatorFactory.deploy(
    owner.address
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
