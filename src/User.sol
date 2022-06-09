// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Factory.sol";
import {IAxelarExecutable} from "@axelar-network/axelar-cgp-solidity/src/interfaces/IAxelarExecutable.sol";
import {IERC20} from "@axelar-network/axelar-cgp-solidity/src/interfaces/IERC20.sol";
import {IAxelarGasReceiver} from "@axelar-network/axelar-cgp-solidity/src/interfaces/IAxelarGasReceiver.sol";

contract User is IAxelarExecutable{

    IAxelarGasReceiver gasReceiver; 
    
    // Address of the user
    address public userAddress;

    address public owner;
    
    // Address of the ERC20 token they own (for now WETH)
    ERC20 public token;
    address public tokenAddress;
    address[] public creators;
    string symbol;

    struct creatorSubscription {

        // Address of a creator they are subscriptions to
        address creatorAddress;

        // Amount to be paid in upcoming intervals
        // Assumes that we pay the same amount every month
        uint256 recurringAmount;
        uint nextEligiblePayoutTimestamp;
        uint256 remainingPaymentTimestamps;
        uint256 interval;
        string symbol;
    }

    mapping(address => creatorSubscription) public subscriptionMapping;


    constructor (address _userAddress, address _tokenAddress, address _owner,address _gateway, address _gasReceiver) IAxelarExecutable(_gateway) {
        userAddress = _userAddress;
        tokenAddress = _tokenAddress;
        owner = _owner;
        gasReceiver = IAxelarGasReceiver(_gasReceiver);
    }

    modifier onlyUser() { 
        require(msg.sender == userAddress);
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    event Transaction(address indexed _creatorAddress, uint256 indexed _timestamp, uint256 indexed _amount);

    function createSubscriptionForCreator(address _creatorAddress, uint256 _recurringAmount, uint256 _nextEligiblePayoutTimestamp, uint256 _remainingPaymentTimestamps, uint256 _interval) public {
        // creatorSubscription memory newSubscription = creatorSubscription(_creatorAddress, completedPayment[], _recurringAmount, _remainingPaymentTimestamps, 0);
        subscriptionMapping[_creatorAddress].creatorAddress = _creatorAddress;
        subscriptionMapping[_creatorAddress].recurringAmount = _recurringAmount;
        subscriptionMapping[_creatorAddress].nextEligiblePayoutTimestamp = _nextEligiblePayoutTimestamp;
        subscriptionMapping[_creatorAddress].remainingPaymentTimestamps = _remainingPaymentTimestamps;
        subscriptionMapping[_creatorAddress].interval = _interval;
        creators.push(_creatorAddress);
    }

    // Solidity does not have a way to pop the first element
    // Could consider doing something more sophisticated to reduce gas fees
    function removeFirstTimestamp(address _creatorAddress, uint256 _time) private {
        creatorSubscription storage creatorSub = subscriptionMapping[_creatorAddress];
        uint256 nextTimestamp = creatorSub.nextEligiblePayoutTimestamp;
        creatorSub.remainingPaymentTimestamps-=1;
        emit Transaction(_creatorAddress, creatorSub.nextEligiblePayoutTimestamp, creatorSub.recurringAmount);
        Factory(owner).reduceFutureEarnings(_creatorAddress, creatorSub.recurringAmount);
        creatorSub.nextEligiblePayoutTimestamp += creatorSub.interval;
        creatorSubscription storage creatorSubUpdated = subscriptionMapping[_creatorAddress];
        Factory(owner).updateUserCreatorInfo(_creatorAddress, userAddress, creatorSubUpdated.recurringAmount, creatorSubUpdated.remainingPaymentTimestamps);
    }

    function sendToAddress(
        string memory destinationChain, 
        string memory destinationAddress, 
        string memory symbol, 
        address receiverAddress,
        uint256 amount
    ) external payable {
        address tokenAddress = gateway.tokenAddresses(symbol);
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
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

    function payForCreatorSubscription(address _creatorAddress, uint256 _time) onlyOwner public  {
        // TODO: Need to check if creator is in the list
        while(subscriptionMapping[_creatorAddress].remainingPaymentTimestamps > 0 && subscriptionMapping[_creatorAddress].nextEligiblePayoutTimestamp < _time) {
            ERC20(tokenAddress).transferFrom(userAddress, _creatorAddress, subscriptionMapping[_creatorAddress].recurringAmount);
            removeFirstTimestamp(_creatorAddress, _time);
        }
    }

    // This would enumerate through every creator and see if they have a pending subscriptions to pay for
    // Don't think this is very efficient
    function payForEligibleSubscriptions(uint256 _time) onlyOwner public {
        uint256 numSubscriptions = creators.length;
        for (uint i = 0; i < numSubscriptions; i++) {
            payForCreatorSubscription(creators[i], _time);
        }
    }

    function getUserAddress() public view returns (address) {
        return userAddress;
    }

    function getUserTokenAddress() public view returns (address) {
        return address(ERC20(tokenAddress));
    }

    function getNumberOfSubscriptions() public view returns(uint256) {
        return creators.length;
    }

    function getERC20Allowance() public view returns(uint256) {
        return ERC20(tokenAddress).allowance(userAddress, address(this));
    }

    function getUserBalance() public view returns (uint256) {
        return ERC20(tokenAddress).balanceOf(userAddress);
    }

    function getCreatorBalance(address _address) public view returns (uint256) {
        return ERC20(tokenAddress).balanceOf(_address);
    }

    function getContractBalance() public view returns (uint256) {
        return ERC20(tokenAddress).balanceOf(address(this));
    }

    function getSubscriptionInfo(address _creatorAddress) 
    public view returns (uint256, uint256, uint256, uint256) {
        creatorSubscription memory creatorSub = subscriptionMapping[_creatorAddress];
        return (creatorSub.recurringAmount, creatorSub.remainingPaymentTimestamps,creatorSub.interval, creatorSub.nextEligiblePayoutTimestamp);
    }

    function getSubscriptionInfoByIndex(uint256 _index)
    public view returns (uint256, uint256, uint256, uint256) {
        return getSubscriptionInfo(creators[_index]);
    }

    function getNextPaymentTimestamp(address _creatorAddress) public view returns (uint256) {
        return subscriptionMapping[_creatorAddress].nextEligiblePayoutTimestamp;
    }

}