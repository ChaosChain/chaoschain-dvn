const { ethers } = require("hardhat");
const fs = require("fs-extra");
const path = require("path");

async function main() {
    const [deployer] = await ethers.getSigners();
    
    console.log("=".repeat(50));
    console.log("🚀 ChaosChain DVN PoC Deployment");
    console.log("=".repeat(50));
    console.log(`Deploying contracts with account: ${deployer.address}`);
    console.log(`Account balance: ${ethers.utils.formatEther(await deployer.getBalance())} ETH`);
    console.log(`Network: ${network.name}`);
    console.log();

    const deploymentResults = {};

    try {
        // 1. Deploy DVN Registry
        console.log("📋 Deploying DVNRegistryPOC...");
        const DVNRegistry = await ethers.getContractFactory("DVNRegistryPOC");
        const dvnRegistry = await DVNRegistry.deploy();
        await dvnRegistry.deployed();
        
        console.log(`✅ DVNRegistryPOC deployed to: ${dvnRegistry.address}`);
        deploymentResults.dvnRegistry = dvnRegistry.address;

        // 2. Deploy DVN Attestation
        console.log("\n🔍 Deploying DVNAttestationPOC...");
        const DVNAttestation = await ethers.getContractFactory("DVNAttestationPOC");
        const dvnAttestation = await DVNAttestation.deploy(dvnRegistry.address);
        await dvnAttestation.deployed();
        
        console.log(`✅ DVNAttestationPOC deployed to: ${dvnAttestation.address}`);
        deploymentResults.dvnAttestation = dvnAttestation.address;

        // 3. Deploy DVN Consensus
        console.log("\n⚖️  Deploying DVNConsensusPOC...");
        const DVNConsensus = await ethers.getContractFactory("DVNConsensusPOC");
        const dvnConsensus = await DVNConsensus.deploy(
            dvnRegistry.address,
            dvnAttestation.address
        );
        await dvnConsensus.deployed();
        
        console.log(`✅ DVNConsensusPOC deployed to: ${dvnConsensus.address}`);
        deploymentResults.dvnConsensus = dvnConsensus.address;

        // 4. Deploy Studio POC
        console.log("\n🏪 Deploying StudioPOC (KiranaAI)...");
        const StudioPOC = await ethers.getContractFactory("StudioPOC");
        const studioPOC = await StudioPOC.deploy(dvnRegistry.address);
        await studioPOC.deployed();
        
        console.log(`✅ StudioPOC deployed to: ${studioPOC.address}`);
        deploymentResults.studioPOC = studioPOC.address;

        // 5. Set up contract connections
        console.log("\n🔗 Setting up contract connections...");
        
        // Set DVN Consensus contract in Attestation contract
        console.log("   Setting DVN Consensus in Attestation contract...");
        await dvnAttestation.setDVNConsensusContract(dvnConsensus.address);
        
        // Set DVN Consensus contract in Studio contract
        console.log("   Setting DVN Consensus in Studio contract...");
        await studioPOC.setDVNConsensusContract(dvnConsensus.address);
        
        // Register Studio in DVN Consensus
        console.log("   Registering Studio in DVN Consensus...");
        await dvnConsensus.registerStudio(studioPOC.address, "KiranaAI-POC-Studio");

        console.log("✅ Contract connections established");

        // 6. Verify deployment
        console.log("\n🔍 Verifying deployment...");
        
        // Check DVN Registry
        const totalVAs = await dvnRegistry.totalRegisteredVAs();
        const totalWAs = await dvnRegistry.totalRegisteredWAs();
        console.log(`   DVN Registry - VAs: ${totalVAs}, WAs: ${totalWAs}`);
        
        // Check DVN Consensus
        const consensusRequirements = await dvnConsensus.getConsensusRequirements();
        console.log(`   DVN Consensus - Min Attestations: ${consensusRequirements[0]}, Threshold: ${consensusRequirements[1]}%`);
        
        // Check Studio
        const studioStats = await studioPOC.getStudioStats();
        console.log(`   Studio - Total Submissions: ${studioStats[0]}`);

        // 7. Save deployment information
        deploymentResults.network = network.name;
        deploymentResults.deployer = deployer.address;
        deploymentResults.deploymentTime = new Date().toISOString();
        deploymentResults.blockNumber = await ethers.provider.getBlockNumber();

        // Save to config file
        const configDir = path.join(__dirname, "..", "config");
        await fs.ensureDir(configDir);
        
        const configFile = path.join(configDir, `deployment-${network.name}.json`);
        await fs.writeJson(configFile, deploymentResults, { spaces: 2 });

        console.log(`\n📄 Deployment configuration saved to: ${configFile}`);

        // 8. Display summary
        console.log("\n" + "=".repeat(50));
        console.log("🎉 DEPLOYMENT SUCCESSFUL!");
        console.log("=".repeat(50));
        console.log("Contract Addresses:");
        console.log(`DVN Registry:    ${deploymentResults.dvnRegistry}`);
        console.log(`DVN Attestation: ${deploymentResults.dvnAttestation}`);
        console.log(`DVN Consensus:   ${deploymentResults.dvnConsensus}`);
        console.log(`Studio POC:      ${deploymentResults.studioPOC}`);
        console.log();
        console.log("Next Steps:");
        console.log("1. Run: npm run setup-demo");
        console.log("2. Register some Verifier Agents");
        console.log("3. Test the full workflow!");
        console.log("=".repeat(50));

    } catch (error) {
        console.error("\n❌ Deployment failed:");
        console.error(error);
        process.exit(1);
    }
}

// Execute the deployment
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    }); 