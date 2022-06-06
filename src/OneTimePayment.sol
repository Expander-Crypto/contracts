// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import {IAxelarExecutable} from "@axelar-network/axelar-cgp-solidity/src/interfaces/IAxelarExecutable.sol";
import {IERC20} from "@axelar-network/axelar-cgp-solidity/src/interfaces/IERC20.sol";
import {IAxelarGasReceiver} from "@axelar-network/axelar-cgp-solidity/src/interfaces/IAxelarGasReceiver.sol";

contract OnTimePayment is IAxelarExecutable {
    IAxelarGasReceiver gasReceiver; 


    constructor(address _gateway, address _gasReceiver) IAxelarExecutable(_gateway) {
        gasReceiver = IAxelarGasReceiver(_gasReceiver);
    }

    function sendToAddress(
        string memory destinationChain, 
        string memory destinationAddress, 
        string memory symbol, 
        uint256 amount
    ) external payable {
        address tokenAddress = gateway.tokenAddresses(symbol);
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
        IERC20(tokenAddress).approve(address(gateway), amount);
        bytes memory payload = abi.encode(amount, symbol, destinationAddress);
        if(msg.value > 0) {
            gasReceiver.payNativeGasForContractCall{ value: msg.value }(
                address(this),
                destinationChain,
                destinationAddress,
                payload,
                msg.sender
            );
        }

        gateway.callContract(
            destinationChain,
            destinationAddress,
            payload
        );
    }

    function _execute(
        string memory sourceChain_,
        string memory sourceAddress_, 
        bytes calldata payload_
    ) internal override {
        address creatorAddress;
        uint256 amount;
        string memory tokenSymbol;
        (amount, tokenSymbol, creatorAddress) = abi.decode(payload_, (uint256, string, address));
        address tokenAddress = gateway.tokenAddresses(tokenSymbol);
        IERC20(tokenAddress).transfer(creatorAddress, amount);
    }
}