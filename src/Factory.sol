// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./User.sol";

contract Factory {

    address owner;

    address[] public creatorAddress;

    mapping(address => uint256) creatorExists;

    User[] public users;

    mapping(address => uint256) creatorFutureEarnings;

    mapping(address => User) public addressToUserMapping;

    mapping(address => mapping(address => uint256)) public userCreatorRecurringAmount;

    mapping(address => address[]) public subscribersForCreator;

    mapping (address => mapping(address => uint256)) public userCreatorTimestampsLeft;

    mapping(address => uint256) public UserExistsMapping;

    constructor(address _owner) {
        owner = _owner;
    }

    modifier ownerOnly() {
        require (msg.sender == owner);
        _;
    }

    function addCreatorAddress (address _creatorAddress) public {
        require(creatorExists[_creatorAddress] == 0, "Creator already exists");
        creatorAddress.push(_creatorAddress);
        creatorExists[_creatorAddress] = 1;
    }

    function addUser(address _userAddress, address _tokenAddress) external {
        require(UserExistsMapping[_userAddress] == 0, "User already exists");
        require(msg.sender == _userAddress, "Only user can call this");
        User newUser = new User(_userAddress, _tokenAddress, address(this));
        users.push(newUser);
        addressToUserMapping[_userAddress] = newUser;
        UserExistsMapping[_userAddress] = 1;
    }

    function addUserToCreator(address _userAddress, address _creatorAddress, uint256 _amount, uint256 _nextTimestamp, uint256 _remainingPaymentTimestamps, uint256 _interval) external {
        require(userCreatorRecurringAmount[_creatorAddress][_userAddress] == 0, "Subscription already exists");
        require(msg.sender == _userAddress, "Only user can call this");
        subscribersForCreator[_creatorAddress].push(_userAddress);
        userCreatorRecurringAmount[_creatorAddress][_userAddress] = _amount;
        creatorFutureEarnings[_creatorAddress] += _amount * _remainingPaymentTimestamps;
        userCreatorTimestampsLeft[_creatorAddress][_userAddress] = _remainingPaymentTimestamps;
        User(address(addressToUserMapping[_userAddress])).createSubscriptionForCreator(_creatorAddress, _amount, _nextTimestamp, _remainingPaymentTimestamps, _interval);
    }

    function userPayoutForCreator(address _user, address _creator, uint256 _time) public {
        User(address(addressToUserMapping[_user])).payForCreatorSubscription(_creator, _time);
    }

    function userPayout(address _user, uint256 _time) public {
        User(address(addressToUserMapping[_user])).payForEligibleSubscriptions(_time);
    }

    function updateUserCreatorInfo(address _creator, address _user, uint256 _amount, uint256 _timestamps) external {
        userCreatorTimestampsLeft[_creator][_user] = _timestamps;
        if (_timestamps == 0) {
            userCreatorRecurringAmount[_creator][_user] = 0;
        } else {
            userCreatorRecurringAmount[_creator][_user] = _amount;
        }

    }

    function reduceFutureEarnings(address _creator, uint256 _amount) public {
        creatorFutureEarnings[_creator] -= _amount;
    }

    function getUserCreatorInfo(address _creator, address _user) public view returns (uint256, uint256, uint256, uint256) {
        return (userCreatorRecurringAmount[_creator][_user], creatorFutureEarnings[_creator], userCreatorTimestampsLeft[_creator][_user], User(address(addressToUserMapping[_user])).getNextPaymentTimestamp(_creator));
    }

    function getNumberOfCreators() public view returns(uint256) {
        return creatorAddress.length;
    }

    function getCreatorExistsMapping(address _creatorAddress) public view returns (uint256) {
        return creatorExists[_creatorAddress];
    }

    function getUserFromAddress(address _userAddress) public view returns (User) {
        return addressToUserMapping[_userAddress];
    }

    function getUserContractAddress(address _userAddress) public view returns(address) {
        return address(addressToUserMapping[_userAddress]);
    }

    function getUserAddressFromIndex(uint256 _index) public view returns (address) {
        return User(address(users[_index])).getUserAddress();
    }

    function getNumberOfUsers() public view returns(uint256) {
        return users.length;
    }

    function allUsers() public view returns(User[] memory coll) {
        return coll;
    }

    function isUserAdded(address _userAddress) public view returns (bool) {
        return UserExistsMapping[_userAddress] == 1;
    }

    function isCreatorAdded(address _creatorAddress) public view returns (bool) {
        return creatorExists[_creatorAddress] == 1;
    }

}