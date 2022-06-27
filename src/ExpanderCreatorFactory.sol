// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import {IAxelarExecutable} from "@axelar-network/axelar-cgp-solidity/src/interfaces/IAxelarExecutable.sol";
import {IAxelarGasReceiver} from "@axelar-network/axelar-cgp-solidity/src/interfaces/IAxelarGasReceiver.sol";

contract ExpanderCreatorFactory {

    address public owner;

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
        string userId;
    }    

    creator[] public creators;

    mapping(bytes32 => bool) public creatorExists;
    mapping(bytes32 => creator) public ExpanderCreatorMapping;

    function getHashedCreatorInfo (string memory _creatorAddress, string memory _chainId, string memory _chainName) public pure returns (bytes32) {
        return keccak256(abi.encode(_creatorAddress, _chainId, _chainName));
    }

    function addCreator(string memory _creatorAddress, string memory _chainId, string memory _chainName, string memory _userId) public {
        bytes32 hashedCreatorInfo = getHashedCreatorInfo(_creatorAddress, _chainId, _chainName);
        require(creatorExists[hashedCreatorInfo] == false, "Creator already exists");
        creator memory newCreator = creator(_creatorAddress, _chainId, _chainName, _userId);
        creators.push(newCreator);
        ExpanderCreatorMapping[hashedCreatorInfo] = newCreator;
        creatorExists[hashedCreatorInfo] = true;
    }

    function getNumberOfCreators() public view returns(uint256) {
        return creators.length;
    }
}