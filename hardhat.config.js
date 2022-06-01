// hardhat.config.js
const {
	alchemyApiKey,
	infuraKey,
	mnemonic,
	BSCSCAN_API_KEY,
	POLYGON_API_KEY,
	AVALANCHE_API_KEY,
	RINKEBY_API_KEY
} = require("./secrets.json");

require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-etherscan");

module.exports = {
	solidity: {
		version: "0.8.0",
		settings: {
			optimizer: {
				enabled: true,
				runs: 1000,
			},
		},
	},
	networks: {
		rinkeby: {
			url: "https://rinkeby.infura.io/v3/" + infuraKey,
			gas: 10000000,
			accounts: { mnemonic: mnemonic },
		},
		kovan: {
			url: `https://eth-kovan.alchemyapi.io/v2/${alchemyApiKey}`,
			accounts: { mnemonic: mnemonic }
		},
		binanceTest: {
			url: "https://data-seed-prebsc-1-s1.binance.org:8545",
			chainId: 97,
			gas: 2100000,
			gasPrice: 20000000000,
			accounts: { mnemonic: mnemonic }
		},
		binanceMain: {
			url: "https://bsc-dataseed.binance.org/",
			chainId: 56,
			gasPrice: 20000000000,
			accounts: { mnemonic: mnemonic }
		},
		polygon: {
			url: "https://rpc-mainnet.maticvigil.com",
			// url: "https://polygon-rpc.com",
			// url: "https://rpc-mainnet.matic.network",
			chainId: 137,
			gasPrice: 20000000000,
			accounts: { mnemonic: mnemonic }
		},
		mumbai: {
			url: "https://matic-mumbai.chainstacklabs.com",
			// url: "https://rpc-mumbai.matic.today",
			// url: "https://rpc-mumbai.maticvigil.com",
			chainId: 80001,
			gasPrice: 20000000000,
			accounts: { mnemonic: mnemonic }
		},
		avalancheTest: {
			url: 'https://api.avax-test.network/ext/bc/C/rpc',
			// url: 'https://api-testnet.snowtrace.io/ext/bc/C/rpc',
			gasPrice: 225000000000,
			chainId: 43113,
			accounts: { mnemonic: mnemonic }
		},
		avalancheMain: {
			url: 'https://api.avax.network/ext/bc/C/rpc',
			gasPrice: 225000000000,
			chainId: 43114,
			accounts: { mnemonic: mnemonic }
		}
	},
	etherscan: {
		apiKey: POLYGON_API_KEY
	}
};
