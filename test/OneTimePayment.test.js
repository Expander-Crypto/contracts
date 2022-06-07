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
const OneTimePayment = require("../build/OneTimePayment.json");

use(solidity);
describe("BasicToken", () => {
  async function deploy(chain) {
    const contract = await deployContract(chain.wallet, OneTimePayment, [
      chain.gateway,
      chain.gasReceiver,
    ]);
    chain.OneTimePayment = contract.address;

    return chain.OneTimePayment;
  }

  it("One time payment works", async () => {
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
    const source = chains.find((chain) => chain.name == "Avalanche");
    const destination = chains.find((chain) => chain.name == "Fantom");
    const senderWallet = new Wallet(private_key);
    const destinationWallet = new Wallet(private_key_2);
    const destinationAddress = destinationWallet.address;
    const symbol = "aUSDC";
    const gasLimit = 3e6;
    const gasPrice = await getGasPrice(source, destination, AddressZero);
    const amount = 10e6;

    for (const chain of [source, destination]) {
      const provider = getDefaultProvider(chain.rpc);
      chain.wallet = senderWallet.connect(provider);
      chain.OneTimePayment = await deploy(chain);
      chain.contract = new Contract(
        chain.OneTimePayment,
        OneTimePayment.abi,
        chain.wallet
      );
      chain.gateway = new Contract(chain.gateway, Gateway.abi, chain.wallet);
      chain.tokenAddress = await chain.gateway.tokenAddresses(symbol);
      chain.token = new Contract(chain.tokenAddress, IERC20.abi, chain.wallet);
    }

    function sleep(ms) {
      return new Promise((resolve) => {
        setTimeout(() => {
          resolve();
        }, ms);
      });
    }
    const balance = await destination.token.balanceOf(
      destinationWallet.address
    );
    expect(balance).to.be.equal(0);
    await (await source.token.approve(source.contract.address, amount)).wait();

    await (
      await source.contract.sendToAddress(
        destination.name,
        destination.contract.address,
        "aUSDC",
        destinationWallet.address,
        amount,
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
    ).to.be.equal(9000000);
  });
});
