// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BlockChainVPN {
    struct User {
        uint256 balance;
        bool isActive;
    }

    mapping(address => User) public users;
    address public owner;
    bool private stopped = false; // Флаг для контроля состояния аварийного выключателя

    // События для логирования действий
    event UserRegistered(address indexed user);
    event DepositMade(address indexed user, uint256 amount);
    event ServiceUsed(address indexed user, uint256 amount);
    event WithdrawalMade(address indexed user, uint256 amount);
    event EmergencyStopped();
    event EmergencyStarted();

    constructor() {
        owner = msg.sender;
    }

    function register() public {
        require(!stopped, "Service is currently stopped");
        require(!users[msg.sender].isActive, "User already registered");
        
        users[msg.sender].isActive = true;
        users[msg.sender].balance = 0;

        emit UserRegistered(msg.sender);
    }

    function deposit() public payable {
        require(!stopped, "Service is currently stopped");
        require(users[msg.sender].isActive, "User not registered or inactive");

        users[msg.sender].balance += msg.value;
        emit DepositMade(msg.sender, msg.value);
    }

    function useService(uint256 amount) public {
        require(!stopped, "Service is currently stopped");
        require(users[msg.sender].isActive, "User not registered or inactive");
        require(users[msg.sender].balance >= amount, "Insufficient balance");

        users[msg.sender].balance -= amount;
        emit ServiceUsed(msg.sender, amount);
    }

    function withdraw(uint256 amount) public {
        require(!stopped, "Service is currently stopped");
        require(users[msg.sender].isActive, "User not registered or inactive");
        require(users[msg.sender].balance >= amount, "Insufficient balance");


        users[msg.sender].balance -= amount;
        payable(msg.sender).transfer(amount);
        emit WithdrawalMade(msg.sender, amount);
    }

    // Функции управления состоянием аварияного отключения
    function emergencyStop() public {
        require(msg.sender == owner, "Only owner can call this function");
        stopped = true;
        emit EmergencyStopped();
    }
    function resumeService() public {
        require(msg.sender == owner, "Only owner can call this function");
        require(stopped, "Service is not stopped");
        stopped = false;
        emit EmergencyStarted();
    }
}