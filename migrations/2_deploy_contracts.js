// migrations/2_deploy_contracts.js

// Load compiled artifacts
const Lottery = artifacts.require('Lottery');

module.exports = async function (deployer) {
    await deployer.deploy(Lottery);
    console.log("Lottery deployed to:", Lottery.address);
};