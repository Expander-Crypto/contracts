const axios = require("axios");
const {
  Contract,
  ContractFactory,
  constants: { AddressZero },
  utils: { keccak256, defaultAbiCoder },
} = require("ethers");
const hre = require("hardhat");
const { ethers } = require("hardhat");
const mumbaiConfig = {
  name: "Polygon",
  chainId: 2504,
  rpc: "http://localhost:8500/4",
  gateway: "0xBF62ef1486468a6bd26Dd669C06db43dEd5B849B",
  gasReceiver: "0xbE406F0189A0B4cf3A05C286473D23791Dd44Cc6",
  tokenName: "Matic",
  tokenSymbol: "MATIC",
  PaymentAddress: "0x5d8e5B15F04Ae466a94a86A5C8868951Ac7D4C8c",
  ExpanderSubscriptionsAddress: "0x006493dEBD9B8C92e26B286EF25E23548dDE44f4",
  ExpanderCreatorFactory: "0x7e48429eB9a63A8a71E2E4266e0aEC7F551aF55f",
  creatorAddress: "0x95f10C78eee9bB36b01EdA48C16f0409eD50F555",
};
const ERC20ABI = require("./ERC20.json");

const fujiConfig = {
  name: "Avalanche",
  rpc: " https://api.avax-test.network/ext/bc/C/rpc",
  chainId: 43113,
  gateway: "0xC249632c2D40b9001FE907806902f63038B737Ab",
  gasReceiver: "0xbE406F0189A0B4cf3A05C286473D23791Dd44Cc6",
  tokenName: "Avax",
  tokenSymbol: "AVAX",
  PaymentAddress: "0x3EADcb9e1c06f0608D3f7624dD6Eaaa1Dd86DDB5",
  ExpanderSubscriptionsAddress: "0x975Cb8020450496a0c265308b365F8f8a9B02628",
  ExpanderCreatorFactoryAddress: "0x29e8f6cB5B5cE0b73fD07f22e531223A5E4A005c",
  USDCContractAddress: "0x57F1c63497AEe0bE305B8852b354CEc793da43bB",
  subscriberAddress: "0x0AFd276709AB4D47D71B48541b08a42Fb597cA86",
};

const payment = {
  chainName: fujiConfig.name,
  chainId: fujiConfig.chainId,
  walletAddress: fujiConfig.subscriberAddress,
  tokenName: "aUSDC",
  tokenSymbol: "aUSDC",
};

const creator = {
  creatorAddress: mumbaiConfig.creatorAddress,
  chainId: mumbaiConfig.chainId,
  chainName: mumbaiConfig.name,
};
const amount = 0.5;
const recurringAmount = ethers.utils.parseEther(String(amount));

const duration = 6;

const interval = 1658286598;

async function getGasPrice(env, source, destination, tokenAddress) {
  if (env == "local") return 1;
  if (env != "testnet") throw Error('env needs to be "local" or "testnet".');
  const api_url = "https://devnet.api.gmp.axelarscan.io";

  const requester = axios.create({ baseURL: api_url });
  const params = {
    method: "getGasPrice",
    destinationChain: destination.name,
    sourceChain: source.name,
  };

  // set gas token address to params
  if (tokenAddress != AddressZero) {
    params.sourceTokenAddress = tokenAddress;
  } else {
    params.sourceTokenSymbol = source.tokenSymbol;
  }
  // send request
  const response = await requester.get("/", { params }).catch((error) => {
    return { data: { error } };
  });
  const result = response.data.result;
  const dest = result.destination_native_token;
  const destPrice = 1e18 * dest.gas_price * dest.token_price.usd;
  return destPrice / result.source_token.token_price.usd;
}

async function ERC20approval() {
  const approvalAmount = ethers.utils.parseEther(String(amount * duration));
  console.log(approvalAmount);
  const [owner] = await ethers.getSigners();
  const axlUSDC = new ethers.Contract(
    fujiConfig.USDCContractAddress,
    ERC20ABI,
    owner
  );
  const transaction = await axlUSDC.approve(
    fujiConfig.PaymentAddress,
    approvalAmount
  );
  console.log(transaction);
  const balance = await axlUSDC.allowance(
    owner.address,
    fujiConfig.PaymentAddress
  );
  console.log(balance);
}

async function getSubscriptionCount() {
  const ExpanderSubscriptions = await hre.ethers.getContractAt(
    "ExpanderSubscriptions",
    fujiConfig.ExpanderSubscriptionsAddress
  );
  const numberOfSubscriptions =
    await ExpanderSubscriptions.getNumberOfSubscriptions({ gasLimit: 8000000 });
  console.log(numberOfSubscriptions);
}
async function startSubscription() {
  const gasPrice = await getGasPrice(
    "testnet",
    fujiConfig,
    mumbaiConfig,
    AddressZero
  );
  const gasLimit = 300000;
  const multiplier = 1.5;
  const gas = gasPrice * gasLimit * multiplier;
  const [owner] = await ethers.getSigners();
  console.log("Deployer address is: ", owner.address);
  console.log("Creator address is", mumbaiConfig.creatorAddress);

  // Give ERC20 approval to payment contract

  // Start subscription
  const ExpanderSubscriptions = await hre.ethers.getContractAt(
    "ExpanderSubscriptions",
    fujiConfig.ExpanderSubscriptionsAddress
  );
  const payoutTimeStamp = Date.now();
  const subscriptionObject = {
    recurringAmount: recurringAmount,
    nextEligiblePayoutTimestamp: payoutTimeStamp,
    remainingPaymentTimestamps: duration,
    interval: interval,
  };
  const bytes32uniqueId = ethers.utils.solidityKeccak256(
    ["string"],
    [String(payoutTimeStamp + mumbaiConfig.creatorAddress)]
  );
  console.log("bytes32uniqueId is", bytes32uniqueId);
  const startSubscriptionTransaction =
    await ExpanderSubscriptions.addSubscription(
      subscriptionObject,
      payment,
      creator,
      bytes32uniqueId,
      { gasLimit: 8000000 }
    );
  console.log(startSubscriptionTransaction);
  const receipt = await startSubscriptionTransaction.wait();
  console.log(receipt);
}

async function startPayment() {
  const gasPrice = await getGasPrice(
    "testnet",
    fujiConfig,
    mumbaiConfig,
    AddressZero
  );
  const gasLimit = 300000;
  const multiplier = 1.5;
  const gas = BigInt(Math.floor(gasPrice * gasLimit * multiplier));
  const [owner] = await ethers.getSigners();
  //   const bytes32uniqueId =
  //     "0x8cf48a9443e7cebdf628eee1affc8597131881f1adfc1e3beba06b94bbe1a789";

  //   const ExpanderSubscriptions = await hre.ethers.getContractAt(
  //     "ExpanderSubscriptions",
  //     fujiConfig.ExpanderSubscriptionsAddress
  //   );

  //   const transaction = await ExpanderSubscriptions.payForCreatorSubscription(
  //     bytes32uniqueId,
  //     Date.now(),
  //     mumbaiConfig.PaymentAddress,
  //     fujiConfig.PaymentAddress,
  //     AddressZero,
  //     { gasLimit: 8000000, value: gas }
  //   );
  //   console.log(transaction);
  //   const receipt = await transaction.wait();
  //   console.log(receipt);
  const Payment = await hre.ethers.getContractAt(
    "Payment",
    fujiConfig.PaymentAddress
  );
  const transaction = await Payment.sendOneTimePayment(
    mumbaiConfig.name,
    mumbaiConfig.PaymentAddress,
    "aUSDC",
    mumbaiConfig.creatorAddress,
    recurringAmount,
    fujiConfig.subscriberAddress,
    fujiConfig.name,
    AddressZero,
    { gasLimit: 8000000, value: gas }
  );
  console.log(transaction);
  const receipt = await transaction.wait();
  console.log(receipt);
}

async function deployPaymentAndGetTokenAddress() {
  //   const gatewayContract = "0xC249632c2D40b9001FE907806902f63038B737Ab";
  //   const gasContract = "0xbE406F0189A0B4cf3A05C286473D23791Dd44Cc6";
  //   const [owner] = await ethers.getSigners();
  //   const Payment = await hre.ethers.getContractFactory("Payment");
  //   const payment = await Payment.deploy(gatewayContract, gasContract);
  //   await payment.deployed();
  //   console.log("Payment has been deployed to:", payment.address);
  const PaymentContract = await hre.ethers.getContractAt(
    "Payment",
    fujiConfig.PaymentAddress
  );

  const transaction = await PaymentContract.getTokenAddress("aUSDC", {
    gasLimit: 8000000,
  });
  console.log(transaction);
}

async function main() {
  const [owner] = await ethers.getSigners();
  // await ERC20approval();
  //   await startSubscription();
  //   await getSubscriptionCount();
  // await startPayment();
  await deployPaymentAndGetTokenAddress();
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
