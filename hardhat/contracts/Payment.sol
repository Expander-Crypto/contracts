// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import {IAxelarExecutable} from "@axelar-network/axelar-cgp-solidity/src/interfaces/IAxelarExecutable.sol";
import {IERC20} from "@axelar-network/axelar-cgp-solidity/src/interfaces/IERC20.sol";
import {IAxelarGasReceiver} from "@axelar-network/axelar-cgp-solidity/src/interfaces/IAxelarGasReceiver.sol";
contract Payment is IAxelarExecutable {

    IAxelarGasReceiver gasReceiver; 

    constructor(address _gateway, address _gasReceiver) IAxelarExecutable(_gateway) {
        gasReceiver = IAxelarGasReceiver(_gasReceiver);
    }

    function sendOneTimePayment(
        string memory destinationChain, 
        string memory destinationAddress, 
        string memory symbol, 
        address receiverAddress,
        uint256 amount, 
        address senderAddress, 
        string memory originChain,
        address tokenContractAddress
    ) public payable  {
        // if (keccak256(abi.encode(destinationChain)) == keccak256(abi.encode(originChain))) {
        //     if (tokenContractAddress == address(0)) {
        //         IERC20(gateway.tokenAddresses(symbol)).transferFrom(senderAddress, receiverAddress, amount);
        //     } else {
        //         IERC20(tokenContractAddress).transferFrom(senderAddress, receiverAddress, amount);
        //     }
        //     return;
        // } 
        address tokenAddress = gateway.tokenAddresses(symbol);
        IERC20(tokenAddress).transferFrom(senderAddress, address(this), amount);
        // IERC20(tokenAddress).approve(address(gateway), amount);
        // bytes memory payload = abi.encode(receiverAddress);

        // if(msg.value > 0) {
        //     gasReceiver.payNativeGasForContractCallWithToken{value: msg.value}(
        //         address(this),
        //         destinationChain,
        //         destinationAddress,
        //         payload,
        //         symbol,
        //         amount,
        //         msg.sender
        //     );
        // }
        // gateway.callContractWithToken(destinationChain, destinationAddress, payload, symbol, amount);
        // gateway.sendToken(destinationChain, destinationAddress, symbol, amount);
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

    function getTokenAddress(string memory symbol) public view returns(address){
        return gateway.tokenAddresses(symbol);
    }
}