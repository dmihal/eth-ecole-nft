const token = '0xf2d1f94310823fe26cfa9c9b6fd152834b8e7849';

const func = async function ({ deployments, getNamedAccounts, getChainId }) {
  const chainId = await getChainId();

  const { deploy, execute, read } = deployments;
  const { deployer } = await getNamedAccounts();

  const deployment = await deploy('ETHEcoleTicket', {
    args: [100, token, ethers.utils.parseEther('1'), 'https://eth-ecole-nft-site.vercel.app/api/'],
    from: deployer,
    deterministicDeployment: true,
  });
  console.log(`Deployed NFT to ${deployment.address}`);
};

module.exports = func;
