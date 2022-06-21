// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./ExpanderFactory.sol";

contract ExpanderCreator is IAxelarExecutable {

    IAxelarGasReceiver gasReceiver; 
    creator public creatorInfo;
    address owner;

    modifier ownerOrContract() {
        require (msg.sender == owner || msg.sender == address(this));
        _;
    }

    constructor(address _gateway, address _gasReceiver, string memory _creatorAddress, string memory _chainId, string memory _chainName, address _owner) IAxelarExecutable(_gateway) {
        gasReceiver = IAxelarGasReceiver(_gasReceiver);
        owner = _owner;
        creatorInfo = creator(_creatorAddress, _chainId, _chainName);
    }

    struct creatorSubscription {
        string subscriberAddress;
        uint256 recurringAmount;
        uint nextEligiblePayoutTimestamp;
        uint256 remainingPaymentTimestamps;
        uint256 interval;
        paymentInfo payment;
    }

    struct paymentInfo {
        string chainName; 
        string chainId;
        string walletAddress;
        string tokenName;
        string tokenSymbol;
    }

    struct creator {
        string creatorAddress;
        string chainId;
        string chainName;
    }

    function sendOneTimePayment(
        string memory destinationChain, 
        string memory destinationAddress, 
        string memory symbol, 
        address receiverAddress,
        uint256 amount, 
        address senderAddress
    ) public payable ownerOrContract  {
        address tokenAddress = gateway.tokenAddresses(symbol);
        // Handle the same chain transfers without Axelar
        if (keccak256(abi.encode(destinationChain)) == keccak256(abi.encode(creatorInfo.chainName))) {
            IERC20(tokenAddress).transferFrom(senderAddress, receiverAddress, amount);
            return;
        }
        IERC20(tokenAddress).transferFrom(senderAddress, address(this), amount);
        IERC20(tokenAddress).approve(address(gateway), amount);
        bytes memory payload = abi.encode(receiverAddress);

        if(msg.value > 0) {
            gasReceiver.payNativeGasForContractCallWithToken{value: msg.value}(
                address(this),
                destinationChain,
                destinationAddress,
                payload,
                symbol,
                amount,
                msg.sender
            );
        }
        gateway.callContractWithToken(destinationChain, destinationAddress, payload, symbol, amount);
    }

    function _executeWithToken(
        string memory,
        string memory,
        bytes calldata payload,
        string memory tokenSymbol,
        uint256 amount
    ) internal override {
        address receiverAddress = abi.decode(payload, (address));
        address tokenAddress = gateway.tokenAddresses(tokenSymbol);
        IERC20(tokenAddress).transfer(receiverAddress, amount);
    }

}