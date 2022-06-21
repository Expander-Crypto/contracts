// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./ExpanderCreator.sol";
import {IAxelarExecutable} from "@axelar-network/axelar-cgp-solidity/src/interfaces/IAxelarExecutable.sol";
import {IAxelarGasReceiver} from "@axelar-network/axelar-cgp-solidity/src/interfaces/IAxelarGasReceiver.sol";

contract ExpanderFactory {

    address owner;

     constructor(address _owner) {
        owner = _owner;
    }

    modifier ownerOnly() {
        require (msg.sender == owner);
        _;
    }
    
    struct creator {
        string creatorAddress;
        string chainId;
        string chainName;
    }    

    ExpanderCreator[] public creators;

    mapping(bytes32 => bool) public creatorExists;
    mapping(bytes32 => ExpanderCreator) public ExpanderCreatorMapping;

    function getHashedCreatorInfo (string memory _creatorAddress, string memory _chainId, string memory _chainName) public pure returns (bytes32) {
        return keccak256(abi.encode(_creatorAddress, _chainId, _chainName));
    }

    function addCreator(address _gateway, address _gasReceiver, string memory _creatorAddress, string memory _chainId, string memory _chainName) ownerOnly external {
        bytes32 hashedCreatorInfo = getHashedCreatorInfo(_creatorAddress, _chainId, _chainName);
        require(creatorExists[hashedCreatorInfo] == false, "Creator already exists");
        ExpanderCreator newCreator = new ExpanderCreator(_gateway, _gasReceiver, _creatorAddress, _chainId, _chainName, owner);
        creators.push(newCreator);
        ExpanderCreatorMapping[hashedCreatorInfo] = newCreator;
        creatorExists[hashedCreatorInfo] = true;
    }
}