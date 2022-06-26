const { expect, use } = require("chai");
const { MockProvider, solidity } = require("ethereum-waffle");
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
const Payment = require("../build/Payment.json");

use(solidity);
describe("Payment Tests", () => {
  async function deploy(chain) {
    const contract = await deployContract(chain.wallet, Payment, [
      chain.gateway,
      chain.gasReceiver,
    ]);
    chain.Payment = contract.address;

    return chain.Payment;
  }

  function sleep(ms) {
    return new Promise((resolve) => {
      setTimeout(() => {
        resolve();
      }, ms);
    });
  }

  const private_key = keccak256(
    defaultAbiCoder.encode(
      ["string"],
      [
        "this is a random string to get a random account. You need to provide the private key for a funded account here.",
      ]
    )
  );
  const private_key_2 = keccak256(
    defaultAbiCoder.encode(["string"], ["this is random"])
  );

  const chains = require("../info/local.json");
  const senderWallet = new Wallet(private_key);
  const destinationWallet = new Wallet(private_key_2);
  const destinationAddress = destinationWallet.address;
  const symbol = "aUSDC";
  const gasLimit = 3e6;
  const amount = 10e6;
  const source = chains.find((chain) => chain.name == "Avalanche");
  const destination = chains.find((chain) => chain.name == "Fantom");
  const gasPrice = 1;

  beforeEach(async () => {
    for (const chain of [source, destination]) {
      const provider = getDefaultProvider(chain.rpc);
      chain.wallet = senderWallet.connect(provider);
      chain.Payment = await deploy(chain);
      chain.contract = new Contract(chain.Payment, Payment.abi, chain.wallet);
      chain.AxelarGateway = new Contract(
        chain.gateway,
        Gateway.abi,
        chain.wallet
      );
      chain.tokenAddress = await chain.AxelarGateway.tokenAddresses(symbol);
      chain.token = new Contract(chain.tokenAddress, IERC20.abi, chain.wallet);
    }
  });
  it("OneTime Payment works for cross chain", async () => {
    const balance = await destination.token.balanceOf(
      destinationWallet.address
    );
    await (await source.token.approve(source.contract.address, amount)).wait();

    await (
      await source.contract.sendOneTimePayment(
        destination.name,
        destination.contract.address,
        "aUSDC",
        destinationWallet.address,
        amount,
        senderWallet.address,
        source.name,
        { value: BigInt(Math.floor(gasLimit * gasPrice)) }
      )
    ).wait();

    while (
      BigInt(await destination.token.balanceOf(destinationWallet.address)) ==
      balance
    ) {
      await sleep(2000);
    }
    expect(
      await destination.token.balanceOf(destinationWallet.address)
    ).to.be.equal(Number(balance) + 9000000);
  });

  it("OneTime Payment works for same chain", async () => {
    const balance = await source.token.balanceOf(destinationWallet.address);
    await (await source.token.approve(source.contract.address, amount)).wait();
    await source.contract.sendOneTimePayment(
      source.name,
      source.contract.address,
      "aUSDC",
      destinationWallet.address,
      amount,
      senderWallet.address,
      source.name,
      { value: BigInt(Math.floor(gasLimit * gasPrice)) }
    );

    while (
      BigInt(await source.token.balanceOf(destinationWallet.address)) == balance
    ) {
      await sleep(2000);
    }
    expect(await source.token.balanceOf(destinationWallet.address)).to.be.equal(
      Number(balance) + 10000000
    );
  });
});
