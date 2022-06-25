const { expect, use } = require("chai");
const { MockProvider, solidity } = require("ethereum-waffle");
const Web3 = require("web3");

const {
  createAndExport,
  utils: { setJSON, deployContract },
  testnetInfo,
  getGasPrice,
} = require("@axelar-network/axelar-local-dev");
const { keccak256, defaultAbiCoder } = require("ethers/lib/utils");

const {
  Wallet,
  getDefaultProvider,
  Contract,
  constants: { AddressZero },
} = require("ethers");

const Gateway = require("../build/IAxelarGateway.json");
const IERC20 = require("../build/IERC20.json");
const ExpanderSubscriptions = require("../build/ExpanderSubscriptions.json");
const Payment = require("../build/Payment.json");
use(solidity);
describe("Subscriptions", () => {
  function sleep(ms) {
    return new Promise((resolve) => {
      setTimeout(() => {
        resolve();
      }, ms);
    });
  }
  async function deploy(chain) {
    const ExpanderSubscriptionsContract = await deployContract(
      chain.wallet,
      ExpanderSubscriptions,
      [chain.chainId, chain.name, chain.wallet.address]
    );
    const PaymentContract = await deployContract(chain.wallet, Payment, [
      chain.gateway,
      chain.gasReceiver,
    ]);
    return [ExpanderSubscriptionsContract.address, PaymentContract.address];
  }

  const owner = keccak256(
    defaultAbiCoder.encode(
      ["string"],
      [
        "this is a random string to get a random account. You need to provide the private key for a funded account here.",
      ]
    )
  );
  const creator = keccak256(
    defaultAbiCoder.encode(["string"], ["this is random"])
  );

  const chains = require("../info/local.json");
  const source = chains.find((chain) => chain.name == "Avalanche");
  const destination = chains.find((chain) => chain.name == "Fantom");
  const ownerWallet = new Wallet(owner);
  const creatorWallet = new Wallet(creator);
  const symbol = "aUSDC";
  const gasLimit = 3e6;
  const gasPrice = 1;
  const amount = 10e6;

  beforeEach(async () => {
    for (const chain of [source, destination]) {
      const provider = getDefaultProvider(chain.rpc);
      chain.wallet = ownerWallet.connect(provider);
      [chain.ExpanderSubscriptionsAddress, chain.PaymentAddress] = await deploy(
        chain
      );
      chain.AxelarGateway = new Contract(
        chain.gateway,
        Gateway.abi,
        chain.wallet
      );
      chain.tokenAddress = await chain.AxelarGateway.tokenAddresses(symbol);
      chain.token = new Contract(chain.tokenAddress, IERC20.abi, chain.wallet);
      chain.ExpanderSubscriptions = new Contract(
        chain.ExpanderSubscriptionsAddress,
        ExpanderSubscriptions.abi,
        chain.wallet
      );
    }
  });

  it("Can add a new subscription", async () => {
    expect(
      Number(
        BigInt(await source.ExpanderSubscriptions.getNumberOfSubscriptions())
      )
    ).to.be.equal(0);
    const subscription = {
      recurringAmount: amount,
      nextEligiblePayoutTimestamp: 100,
      remainingPaymentTimestamps: 6,
      interval: 100,
    };
    const payment = {
      chainName: source.name,
      chainId: source.chainId,
      walletAddress: ownerWallet.address,
      tokenName: source.tokenName,
      tokenSymbol: source.tokenSymbol,
    };
    const creator = {
      creatorAddress: creatorWallet.address,
      chainId: String(destination.chainId),
      chainName: destination.name,
    };
    const uniqueId = keccak256(
      defaultAbiCoder.encode(
        ["string"],
        [
          String(subscription.nextEligibleTimestamp) +
            String(payment.walletAddress),
        ]
      )
    );
    await source.ExpanderSubscriptions.addSubscription(
      subscription,
      payment,
      creator,
      uniqueId
    );
    expect(
      Number(
        BigInt(await source.ExpanderSubscriptions.getNumberOfSubscriptions())
      )
    ).to.be.equal(1);

    // expect(
    //   Number(BigInt(await source.FactoryContract.getNumberOfCreators()))
    // ).to.be.equal(0);
    // await source.FactoryContract.addCreator(
    //   creatorWallet.address,
    //   String(source.chainId),
    //   source.name,
    //   "hello"
    // );
    // expect(
    //   Number(BigInt(await source.FactoryContract.getNumberOfCreators()))
    // ).to.be.equal(1);
  });

  //   it("Creator can only sign up once", async () => {
  //     await source.FactoryContract.addCreator(
  //       creatorWallet.address,
  //       String(source.chainId),
  //       source.name,
  //       "hello"
  //     );
  //     await expect(
  //       source.FactoryContract.addCreator(
  //         creatorWallet.address,
  //         String(source.chainId),
  //         source.name,
  //         "hello"
  //       )
  //     ).to.be.revertedWith("Creator already exists");
  //   });

  // it("sendOneTimePayment works as intended for same chain", async () => {
  //   const balance = await source.token.balanceOf(creatorWallet.address);
  //   await (
  //     await source.token.approve(source.CreatorContract.address, amount)
  //   ).wait();
  //   await (
  //     await source.CreatorContract.sendOneTimePayment(
  //       source.name,
  //       source.CreatorContract.address,
  //       symbol,
  //       creatorWallet.address,
  //       amount,
  //       ownerWallet.address,
  //       { value: BigInt(Math.floor(gasLimit * gasPrice)) }
  //     )
  //   ).wait();

  //   while (
  //     BigInt(await source.token.balanceOf(creatorWallet.address)) == balance
  //   ) {
  //     await sleep(2000);
  //   }
  //   expect(await source.token.balanceOf(creatorWallet.address)).to.be.equal(
  //     Number(balance) + 10000000
  //   );
  // });

  // it("sendOneTimePayment works as intended for cross chain", async () => {
  //   const balance = await destination.token.balanceOf(creatorWallet.address);
  //   await (
  //     await source.token.approve(source.CreatorContract.address, amount)
  //   ).wait();
  //   await (
  //     await source.CreatorContract.sendOneTimePayment(
  //       destination.name,
  //       destination.CreatorContract.address,
  //       symbol,
  //       creatorWallet.address,
  //       amount,
  //       ownerWallet.address,
  //       { value: BigInt(Math.floor(gasLimit * gasPrice)) }
  //     )
  //   ).wait();

  //   while (
  //     BigInt(await destination.token.balanceOf(creatorWallet.address)) ==
  //     balance
  //   ) {
  //     await sleep(2000);
  //   }
  //   expect(
  //     await destination.token.balanceOf(creatorWallet.address)
  //   ).to.be.equal(Number(balance) + 9000000);
  // });
});
