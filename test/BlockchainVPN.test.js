const BlockchainVPN = artifacts.require("BlockchainVPN");

contract("BlockchainVPN", (accounts) => {
  let blockchainVPN;

  before(async () => {
    blockchainVPN = await BlockchainVPN.new([accounts[0], accounts[1]], 2);
  });

  it("should register a user", async () => {
    await blockchainVPN.register({ from: accounts[0] });
    const user = await blockchainVPN.users(accounts[0]);
    assert(user.isActive, "User should be active after registration");
  });

  it("should deposit and update balance", async () => {
    await blockchainVPN.deposit({
      from: accounts[0],
      value: web3.utils.toWei("1", "ether"),
    });
    const user = await blockchainVPN.users(accounts[0]);
    assert.equal(user.balance.toString(), web3.utils.toWei("1", "ether"), "Balance should be 1 ether after deposit");
  });

  it("should allow service addition by owner only", async() => {
    const servicePrice = web3.utils.toWei("0.1", "ether");
    await blockchainVPN.addService(servicePrice, { from: accounts[0] });
    const service = await blockchainVPN.services(0);
    assert.equal(service.basePrice.toString(), servicePrice, "Service price should be set correctly");
  });

  it("should allow service usage", async () => {
    const servicePrice = web3.utils.toWei("0.1", "ether");

    await blockchainVPN.deposit({ from: accounts[0], value: web3.utils.toWei("1", "ether") });
    await blockchainVPN.addService(servicePrice, { from: accounts[0] });
    await blockchainVPN.useService(0, { from: accounts[0] });
    const user = await blockchainVPN.users(accounts[0]);
    assert(user.totalSpent > 0, "Users total spent must be updated after using service");
  });

  it("should allow withdrowal", async () => {
    const withdrawAmount = web3.utils.toWei("0.5", "ether");
    await blockchainVPN.withdraw(withdrawAmount, { from: accounts[0] });
    const user = await blockchainVPN.users(accounts[0]);
    assert(user.balance.toString() < web3.utils.toWei("0.5", "ether"), "Users balance should decrease after withdrawal");
  });

  it("should handle multi-sig operations", async () => {
    const operationType = "emergencyStop";
    const result = await blockchainVPN.initiateOperation(operationType, { from: accounts[0] });
    const operationId = result.logs[0].args.operationId;
    await blockchainVPN.confirmOperation(operationId, { from: accounts[1] });
    const operation = await blockchainVPN.multiSigOperations(operationId);
    assert(operation.executed, "Operation should be executed after required confirmations");
  });

  it("should change service price based on usage", async () => {
    const initialServicePrice = web3.utils.toWei("0.1", "ether");
    await blockchainVPN.register({ from: accounts[1] });
    await blockchainVPN.deposit({ from: accounts[1], value: web3.utils.toWei("1", "ether") });
    await blockchainVPN.addService(initialServicePrice, { from: accounts[0] });
    await blockchainVPN.useService(0, { from: accounts[1] });
    
    await new Promise(resolve => setTimeout(resolve, 2000));
    const priceAfterUsage = await blockchainVPN.calculatePrice(0);
    assert.notEqual(priceAfterUsage.toString(), initialServicePrice, "Service price should change based on usage and time");
  });
});
