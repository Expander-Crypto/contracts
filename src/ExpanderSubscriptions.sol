// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import {IERC20} from "@axelar-network/axelar-cgp-solidity/src/interfaces/IERC20.sol";
import "./Payment.sol";
contract ExpanderSubscriptions {

    address public owner;
    creatorSubscription[] public subscriptions;
    mapping(bytes32 => creatorSubscription) public subscriptionMapping;
    string chainName;
    string chainId;
    modifier ownerOrContract() {
        require (msg.sender == owner || msg.sender == address(this));
        _;
    }

    constructor(string memory _chainId, string memory _chainName, address _owner) {
        owner = _owner;
        chainName = _chainName;
        chainId = _chainId;
    }

    struct creatorSubscription {
        paymentInfo payment;
        creatorInfo creator;
        subscriptionInfo subscription;
    }

    // function addSubscription(bytes32 _uniqueId) public {
        
    // }
    function addSubscription(
        subscriptionInfo memory subscription,
        paymentInfo memory payment,
        creatorInfo memory creator,
        bytes32 _uniqueId
    ) public {
        require(keccak256(abi.encode(payment.chainName)) == keccak256(abi.encode(chainName)), "Should be on the same chain");
        creatorSubscription memory newSubscription = creatorSubscription(payment, creator, subscription); 
        subscriptions.push(newSubscription);
        subscriptionMapping[_uniqueId] = newSubscription;
    }

    function updatePayment(bytes32 _uniqueId) public {
        creatorSubscription storage sub = subscriptionMapping[_uniqueId];
        sub.subscription.remainingPaymentTimestamps -=1;
        sub.subscription.nextEligiblePayoutTimestamp+= sub.subscription.interval;
    }

    event PaymentInitiated(string destinationChain, 
        string destinationAddress, 
        string symbol, 
        address receiverAddress,
        uint256 amount, 
        address senderAddress, 
        string originChain);

    // Calling this will at most only pay for one subscription
    function payForCreatorSubscription(
        bytes32 _uniqueId, uint256 _time, 
        string memory _paymentCreatorContractAddress, 
        address _paymentSubscriberContractAddress) public payable {
        creatorSubscription memory sub = subscriptionMapping[_uniqueId];
        paymentInfo memory payment = sub.payment;
        creatorInfo memory creator = sub.creator;
        subscriptionInfo memory subscription = sub.subscription;
        if(subscription.remainingPaymentTimestamps > 0 && subscription.nextEligiblePayoutTimestamp < _time) {
            updatePayment(_uniqueId);
                emit PaymentInitiated(creator.chainName,  
                    _paymentCreatorContractAddress,
                    payment.tokenSymbol,
                    creator.creatorAddress,
                    subscription.recurringAmount,
                    payment.walletAddress,
                    payment.chainName);
                Payment(_paymentSubscriberContractAddress).sendOneTimePayment{value: msg.value}(
                    creator.chainName,  
                    _paymentCreatorContractAddress,
                    payment.tokenSymbol,
                    creator.creatorAddress,
                    subscription.recurringAmount,
                    payment.walletAddress,
                    payment.chainName
                );
        }
    }

    function getNumberOfSubscriptions() public view returns(uint256) {
        return subscriptions.length;
    }

    function getSubscription(bytes32 _uniqueId) public view returns(creatorSubscription memory) {
        return subscriptionMapping[_uniqueId];
    }

    struct subscriptionInfo {
        uint256 recurringAmount;
        uint256 nextEligiblePayoutTimestamp;
        uint256 remainingPaymentTimestamps;
        uint256 interval;
    }

    struct paymentInfo {
        string chainName; 
        string chainId;
        address walletAddress;
        string tokenName;
        string tokenSymbol;
    }

    struct creatorInfo {
        address creatorAddress;
        string chainId;
        string chainName;
    }
}