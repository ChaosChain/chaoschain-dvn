# ChaosChain DVN PoC - Setup Guide

This guide will walk you through setting up and running the ChaosChain Decentralized Verification Network (DVN) Proof-of-Concept.

## 📋 Prerequisites

- **Node.js** v16 or higher
- **npm** or **yarn**
- **Git**
- **Ethereum wallet** with Sepolia testnet ETH
- **Infura account** (or alternative RPC provider)

## 🚀 Quick Start

### 1. Installation

```bash
# Clone the repository (if not already done)
git clone <repository-url>
cd chaoschain-dvn

# Install dependencies
npm install

# Copy environment configuration
cp config/environment.example .env
```

### 2. Environment Configuration

Edit the `.env` file with your settings:

```bash
# Required: Your private key for deployment
PRIVATE_KEY=your_private_key_without_0x_prefix

# Required: Sepolia RPC URL
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_INFURA_PROJECT_ID

# Optional: For contract verification
ETHERSCAN_API_KEY=your_etherscan_api_key

# Optional: For IPFS integration (Phase 2)
IPFS_NODE_URL=https://ipfs.infura.io:5001
```

⚠️ **Security Note**: Never commit your actual private keys to version control!

### 3. Get Sepolia Testnet ETH

You'll need Sepolia ETH for deployment and testing:

- **Chainlink Faucet**: https://faucets.chain.link/sepolia
- **Alchemy Faucet**: https://sepoliafaucet.com/
- **Infura Faucet**: https://www.infura.io/faucet/sepolia

Recommended: Get at least 0.5 ETH for deployment and demo operations.

### 4. Compile Contracts

```bash
npm run compile
```

Expected output:
```
Compiling 5 files with 0.8.30
Compilation finished successfully
```

### 5. Deploy to Sepolia

```bash
npm run deploy:sepolia
```

Expected output:
```
🚀 ChaosChain DVN PoC Deployment
==================================================
Deploying contracts with account: 0x...
Account balance: 0.5 ETH
Network: sepolia

📋 Deploying DVNRegistryPOC...
✅ DVNRegistryPOC deployed to: 0x...

🔍 Deploying DVNAttestationPOC...
✅ DVNAttestationPOC deployed to: 0x...

⚖️  Deploying DVNConsensusPOC...
✅ DVNConsensusPOC deployed to: 0x...

🏪 Deploying StudioPOC (KiranaAI)...
✅ StudioPOC deployed to: 0x...

🔗 Setting up contract connections...
✅ Contract connections established

🎉 DEPLOYMENT SUCCESSFUL!
```

The deployment configuration will be saved to `config/deployment-sepolia.json`.

## 🧪 Testing

### Run Unit Tests

```bash
npm test
```

### Run Specific Test

```bash
npx hardhat test tests/unit/DVNRegistry.test.js
```

### Test with Gas Reporting

```bash
REPORT_GAS=true npm test
```

## 📊 Contract Verification (Optional)

To verify contracts on Etherscan:

```bash
# Set your Etherscan API key in .env first
ETHERSCAN_API_KEY=your_api_key

# Verify all contracts
npm run verify-deployment
```

## 🎭 Demo Workflow

### Phase 1: Contract Interaction Demo

After successful deployment, you can interact with the contracts directly:

```bash
# Open Hardhat console
npx hardhat console --network sepolia

# Load deployment configuration
const config = require('./config/deployment-sepolia.json');

# Get contract instances
const DVNRegistry = await ethers.getContractFactory("DVNRegistryPOC");
const dvnRegistry = DVNRegistry.attach(config.dvnRegistry);

const StudioPOC = await ethers.getContractFactory("StudioPOC");
const studio = StudioPOC.attach(config.studioPOC);

# Register a verifier agent
const [deployer] = await ethers.getSigners();
const agentId = ethers.utils.formatBytes32String("verifier-001");
await dvnRegistry.registerAgent(agentId, 1, ""); // 1 = VERIFIER

# Stake some ETH
await dvnRegistry.mockStake({ value: ethers.utils.parseEther("0.01") });

# Check registration
console.log(await dvnRegistry.isRegisteredVerifier(deployer.address));
```

### Phase 2: Python Agent Scripts (Coming Soon)

The next phase will include Python scripts that simulate:
- Worker Agents submitting inventory verification tasks
- Verifier Agents evaluating submissions
- Automatic consensus processing

## 🔧 Development

### Project Structure

```
chaoschain-dvn/
├── contracts/           # Solidity smart contracts
├── scripts/            # Deployment and utility scripts
├── tests/              # Test suite
├── docs/               # Documentation
├── config/             # Configuration files
├── agents/             # Agent implementations (Phase 2)
└── demo/               # Demo scripts (Phase 2)
```

### Key Contracts

- **DVNRegistryPOC**: Agent registration and staking
- **StudioPOC**: KiranaAI inventory verification studio
- **DVNAttestationPOC**: Verifier agent attestations
- **DVNConsensusPOC**: Consensus processing and finalization

### Adding New Studios

To create a new Studio type:

1. Create a contract implementing `IStudioPolicy`
2. Deploy it with DVN Registry reference
3. Register it with DVN Consensus contract
4. Set the DVN Consensus contract address in your Studio

Example:
```solidity
contract MyStudio is IStudioPolicy {
    constructor(address _dvnRegistry) {
        dvnRegistryContract = _dvnRegistry;
    }
    // Implement required functions...
}
```

## 🐛 Troubleshooting

### Common Issues

**1. "insufficient funds for intrinsic transaction cost"**
- Solution: Get more Sepolia ETH from faucets

**2. "nonce too high"**
- Solution: Reset your wallet nonce or wait for pending transactions

**3. "contract not deployed"**
- Solution: Ensure deployment completed successfully, check `config/deployment-sepolia.json`

**4. Compilation errors**
- Solution: Run `npm run clean` then `npm run compile`

### Debug Mode

Enable debug logging:
```bash
ENABLE_DEBUG_LOGS=true npm run deploy:sepolia
```

### Reset Local Environment

```bash
npm run clean
rm -rf cache/ artifacts/
npm install
npm run compile
```

## 📞 Support

- **Issues**: https://github.com/chaoschain/dvn-poc/issues
- **Documentation**: `docs/` directory
- **Architecture**: See `docs/ARCHITECTURE.md`

## 🚀 Next Steps

After successful setup:

1. **Test Contract Functions**: Use Hardhat console to interact with deployed contracts
2. **Register Agents**: Create multiple verifier and worker agents
3. **Submit Test Work**: Create mock inventory verification submissions
4. **Monitor Events**: Watch for DVN events on Sepolia Etherscan
5. **Phase 2**: Wait for Python agent scripts to automate the full workflow

Congratulations! You now have a working DVN PoC deployment on Sepolia testnet. 🎉 