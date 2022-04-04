const HDWalletProvider = require('@truffle/hdwallet-provider');
require('dotenv').config()

module.exports = {
    // See <http://truffleframework.com/docs/advanced/configuration>
    // to customize your Truffle configuration!
    networks: {
        // 指定truffle develop打开的私链端口为8545
        develop: {
            port: 8545
        },
        // Ganache部署的网络名，由自己定义
        ganache: {
            host: "127.0.0.1",     // Localhost (default: none)
            port: 7545,            // Standard Ethereum port (default: none)
            network_id: "*",       // Any network (default: none)
        },
        rinkeby: {
            provider: () => {
                return new HDWalletProvider(process.env.MNEMONIC, process.env.RINKEBY_RPC_URL);
            },
            network_id: "4",
            skipDryRun: true,
        },
    },

    // Configure your compilers
    compilers: {
        solc: {
            version: "0.8.2",    // Fetch exact version from solc-bin (default: truffle's version)
        }
    },
    api_keys: {
        etherscan: process.env.ETHERSCAN_API_KEY
    },
    plugins: [
        "truffle-plugin-verify"
    ]
};
