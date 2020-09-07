const { ethers, providers } = require('ethers');
const config = require('../../../config');
const fs = require('fs');
const path = require('path');
const appRootPath = require('app-root-path');
const abiCoder = require('web3-eth-abi');

const ethProvider = new providers.JsonRpcProvider(
  config.eth_provider,
);

const getAbi = () => {
  const json = fs.readFileSync(path.join(appRootPath.path, './build/__build_UniswapV2Factory_sol_UniswapV2Pair.abi'));
  return JSON.parse(json.toString());
};

const abi = getAbi();
const contract = new ethers.Contract(
  process.env.pair || config.pair,
  abi,
  ethProvider
);

async function main () {
  const reserves = await contract.getReserves();
  console.info('Reserves', reserves);
}

main();