// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BlockchainVPN {
    struct User {
        uint256 balance;
        bool isActive;
        uint256 totalSpent;
        uint256 reputation;
    }

    struct Service {
        uint256 basePrice;
        uint256 demandFactor;
        bool isActive;
        uint256 lastUsed;
        uint256 usageCount;
    }

    struct MultiSigOperation {
        address initiator;
        bool executed;
        mapping(address => bool) confirmations;
        uint numConfirmations;
    }

    mapping(address => User) public users;
    mapping(uint256 => Service) public services;
    mapping(bytes32 => MultiSigOperation) public multiSigOperations;

    address public owner;
    address[] public admins;
    uint256 public requiredConfirmations;
    bool private stopped = false;
    uint256 public serviceCount;
    uint256 public totalUsage;

    // События для логирования действий
    event UserRegistered(address indexed user);
    event DepositMade(address indexed user, uint256 amount);
    event ServiceUsed(address indexed user, uint256 serviceId, uint256 amount);
    event WithdrawalMade(address indexed user, uint256 amount);
    event EmergencyStopped();
    event EmergencyStarted();
    event ServiceAdded(uint256 serviceId, uint256 price);
    event ServicePriceChanged(uint256 serviceId, uint256 newPrice);
    event ReputationChanged(address indexed user, uint256 newReputation);
    event OperationInitiated(bytes32 operationId, address initiator);
    event OperationConfirmed(bytes32 operationId, address admin);
    event OperationExecuted(bytes32 operationId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyAdmin() {
        require(isAdmin(msg.sender), "Only admin can call this function");
        _;
    }

    constructor(address[] memory _admins, uint256 _requiredConfirmations) {
        require(_admins.length > 0, "Admins required");
        require(_requiredConfirmations > 0 && _requiredConfirmations <= _admins.length, "Invalid number of required confirmations");

        owner = msg.sender;
        admins = _admins;
        requiredConfirmations = _requiredConfirmations;
    }

    function isAdmin(address user) public view returns (bool) {
        for (uint i = 0; i < admins.length; i++) {
            if (admins[i] == user) {
                return true;
            }
        }
        return false;
    }

    function register() public {
        require(!stopped, "Service is currently stopped");
        require(!users[msg.sender].isActive, "User already registered");
        
        users[msg.sender] = User({balance: 0, isActive: true, totalSpent: 0, reputation: 0});
        emit UserRegistered(msg.sender);
    }

    function addService(uint256 price) public onlyOwner {
        services[serviceCount] = Service({basePrice: price, demandFactor: 1, isActive: true, lastUsed: 0, usageCount: 0});
        emit ServiceAdded(serviceCount, price);
        serviceCount++;
    }

    function changeServicePrice(uint256 serviceId, uint256 newPrice) public onlyOwner {
        require(services[serviceId].isActive, "Service declined connect");
        services[serviceId].basePrice = newPrice;
        emit ServicePriceChanged(serviceId, newPrice);
    }

    function deposit() public payable {
        require(!stopped, "Service is currently stopped");
        require(users[msg.sender].isActive, "User not registered or inactive");

        users[msg.sender].balance += msg.value;
        emit DepositMade(msg.sender, msg.value);
    }

    function useService(uint256 serviceId) public {
        require(!stopped, "Service is currently stopped");
        Service storage service = services[serviceId];
        User storage user = users[msg.sender];

        require(user.isActive, "User not registered or inactive");
        uint256 servicePrice = calculatePrice(serviceId);
        require(user.balance >= servicePrice, "Insufficient balance");
        require(service.isActive, "Service declined connection");

        user.balance -= servicePrice;
        user.totalSpent += servicePrice;
        user.reputation += 1;
        totalUsage += 1;
        service.lastUsed = block.timestamp;
        service.usageCount += 1;

        emit ServiceUsed(msg.sender, serviceId, servicePrice);
        emit ReputationChanged(msg.sender, user.reputation);
    }

    function calculatePrice(uint256 serviceId) public view returns (uint256) {
        Service storage service = services[serviceId];
        require(service.isActive, "Service declined connection");

        uint256 timeSinceLastUsed = block.timestamp - service.lastUsed;
        uint256 usageIntensity = service.usageCount / (timeSinceLastUsed / 1 hours + 1);

        uint256 priceAdjustmentFactor = 1 + (service.demandFactor * usageIntensity);

        if (timeSinceLastUsed > 1 days) {
            priceAdjustmentFactor /= 2;
        }

        // Пик и внепик
        uint256 hourOfDay = (block.timestamp / 1 hours) % 24;
        if (hourOfDay >= 8 && hourOfDay <= 18) {
            priceAdjustmentFactor += priceAdjustmentFactor / 10;
        } else {
            priceAdjustmentFactor -= priceAdjustmentFactor / 20;
        }

        uint256 finalPrice = service.basePrice * priceAdjustmentFactor;

        // Подумать, нужна ли мин. и макс. цена?
        uint256 minPrice = service.basePrice / 2;
        uint256 maxPrice = service.basePrice * 3;

        if (finalPrice < minPrice) {
            finalPrice = minPrice;
        } else if (finalPrice > maxPrice) {
            finalPrice = maxPrice;
        }

        return finalPrice;
    }

    function withdraw(uint256 amount) public {
        require(!stopped, "Service is currently stopped");
        require(users[msg.sender].isActive, "User not registered or inactive");
        require(users[msg.sender].balance >= amount, "Insufficient balance");


        users[msg.sender].balance -= amount;
        payable(msg.sender).transfer(amount);
        emit WithdrawalMade(msg.sender, amount);
    }

    function initiateOperation(string memory operationType) public onlyAdmin returns (bytes32) {
        bytes32 operationId = keccak256(abi.encodePacked(operationType, block.timestamp, msg.sender));
        MultiSigOperation storage operation = multiSigOperations[operationId];
        operation.initiator = msg.sender;
        operation.executed = false;
        operation.numConfirmations = 1;
        operation.confirmations[msg.sender] = true;

        emit OperationInitiated(operationId, msg.sender);
        return operationId;
    }

    function confirmOperation(bytes32 operationId) public onlyAdmin {
        MultiSigOperation storage operation = multiSigOperations[operationId];
        require(!operation.confirmations[msg.sender], "Operation already confirmed by this admin");
        require(!operation.executed, "Operation already executed");

        operation.confirmations[msg.sender] = true;
        operation.numConfirmations++;

        emit OperationConfirmed(operationId, msg.sender);

        if (operation.numConfirmations >= requiredConfirmations && !operation.executed) {
            executeOperation(operationId);
        }
    }

    function executeOperation(bytes32 operationId) internal {
        MultiSigOperation storage operation = multiSigOperations[operationId];
        require(operation.numConfirmations >= requiredConfirmations, "Not enough confirmations to execute operation");
        require(!operation.executed, "Operation already executed");

        if (keccak256(abi.encodePacked(operation.initiator)) == keccak256(abi.encodePacked("emergencyStop"))) {
            emergencyStop();
        } else if (keccak256(abi.encodePacked(operation.initiator)) == keccak256(abi.encodePacked("resumeService"))) {
            resumeService();
        }

        operation.executed = true;
        emit OperationExecuted(operationId);
    }

    // Функции управления состоянием аварияного отключения
    function emergencyStop() internal {
        require(msg.sender == owner || isAdmin(msg.sender), "Only owner or admin can call this function");
        stopped = true;
        emit EmergencyStopped();
    }
    function resumeService() internal {
        require(msg.sender == owner || isAdmin(msg.sender), "Only owner or admin can call this function");
        require(stopped, "Service is not stopped");
        stopped = false;
        emit EmergencyStarted();
    }
}