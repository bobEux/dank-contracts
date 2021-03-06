/**
 * @type import('hardhat/types').HardhatRuntimeEnvironment
 */
const func = async function (hre) {
  const { deployments: { deploy }, getNamedAccounts } = hre;
  const { deployer } = await getNamedAccounts();

  await deploy('WrappedERC20', {
    args: ['Wrapped XDAI', 'WXDAI'],
    from: deployer,
    log: true,
  });
};
module.exports = func;
module.exports.tags = ['WrappedERC20'];
