const BlockchainVPN = artifacts.require("BlockchainVPN");

contract("BlockchainVPN", (accounts) => {
  let blockchainVPN;

  before(async () => {
    blockchainVPN = await BlockchainVPN.new();
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
});
