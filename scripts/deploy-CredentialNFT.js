// scripts/deploy.js
require("@nomiclabs/hardhat-ethers");

async function main() {

	const CrednetialNFT = await ethers.getContractFactory("CrednetialNFT");
	console.log("Deploying ...");
	const box = await CrednetialNFT.deploy();
	console.log("CrednetialNFT :", box.address);
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
