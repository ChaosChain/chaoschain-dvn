const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
    console.log("🔧 ChaosChain DVN PoC - Complete Deployment");
    console.log("=".repeat(50));

    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with account:", deployer.address);
    
    const balance = await deployer.getBalance();
    console.log("Account balance:", ethers.utils.formatEther(balance), "ETH");
    
    const network = await ethers.provider.getNetwork();
    console.log("Network:", network.name);

    // Previously deployed contract addresses (from your output)
    const deployedAddresses = {
        DVNRegistryPOC: "0x5A6207a71c49037316aD1C37E26df2E40aB599fE",
        DVNAttestationPOC: "0x950B75d0769dfC164f030976cEAd4C89BCA5541F",
        DVNConsensusPOC: "0x33807533035915AA6A461E4d0c7b136Ea0771dDa"
    };

    console.log("\n📋 Previously deployed contracts:");
    for (const [name, address] of Object.entries(deployedAddresses)) {
        console.log(`✅ ${name}: ${address}`);
    }

    try {
        // Deploy the remaining StudioPOC contract
        console.log("\n🏪 Deploying StudioPOC (KiranaAI)...");
        
        const StudioPOC = await ethers.getContractFactory("StudioPOC");
        const studio = await StudioPOC.deploy(deployedAddresses.DVNRegistryPOC);
        await studio.deployed();
        
        console.log("✅ StudioPOC deployed to:", studio.address);
        deployedAddresses.StudioPOC = studio.address;

        // Get contract instances for configuration
        console.log("\n🔗 Setting up contract connections...");
        
        const dvnRegistry = await ethers.getContractAt("DVNRegistryPOC", deployedAddresses.DVNRegistryPOC);
        const dvnAttestation = await ethers.getContractAt("DVNAttestationPOC", deployedAddresses.DVNAttestationPOC);
        const dvnConsensus = await ethers.getContractAt("DVNConsensusPOC", deployedAddresses.DVNConsensusPOC);

        // Configuration
        console.log("\n⚙️  Configuring contracts...");
        
        // 1. Set DVN Consensus contract address in Attestation contract
        console.log("1. Setting DVN Consensus address in Attestation contract...");
        const tx1 = await dvnAttestation.setDVNConsensusContract(dvnConsensus.address);
        await tx1.wait();
        console.log("✅ DVN Consensus address set in Attestation contract");
        
        // 2. Register Studio with DVN Consensus
        console.log("2. Registering Studio with DVN Consensus...");
        const tx2 = await dvnConsensus.registerStudio(studio.address, "KiranaAI-POC-Studio");
        await tx2.wait();
        console.log("✅ Studio registered with DVN Consensus");
        
        // 3. Set DVN contracts in Studio
        console.log("3. Setting DVN contract addresses in Studio...");
        const tx3 = await studio.setDVNConsensusContract(dvnConsensus.address);
        await tx3.wait();
        console.log("✅ DVN contract addresses set in Studio");

        // Save deployment information
        const deploymentData = {
            network: network.name,
            chainId: network.chainId,
            deployer: deployer.address,
            timestamp: new Date().toISOString(),
            contracts: deployedAddresses,
            gasUsed: {
                DVNRegistryPOC: "Previously deployed",
                DVNAttestationPOC: "Previously deployed", 
                DVNConsensusPOC: "Previously deployed",
                StudioPOC: (await studio.deployTransaction.wait()).gasUsed.toString()
            }
        };

        // Ensure ignition/deployments directory exists
        const deploymentsDir = path.join("ignition", "deployments");
        if (!fs.existsSync(deploymentsDir)) {
            fs.mkdirSync(deploymentsDir, { recursive: true });
        }

        const deploymentFile = path.join(deploymentsDir, `chain-${network.chainId}.json`);
        fs.writeFileSync(deploymentFile, JSON.stringify(deploymentData, null, 2));

        console.log("\n" + "=".repeat(50));
        console.log("🎉 DEPLOYMENT COMPLETED SUCCESSFULLY!");
        console.log("=".repeat(50));

        console.log("\n📋 Final Contract Addresses:");
        for (const [name, address] of Object.entries(deployedAddresses)) {
            console.log(`   ${name}: ${address}`);
        }

        console.log("\n💾 Deployment details saved to:", deploymentFile);
        
        console.log("\n🔗 Sepolia Etherscan Links:");
        for (const [name, address] of Object.entries(deployedAddresses)) {
            console.log(`   ${name}: https://sepolia.etherscan.io/address/${address}`);
        }

        console.log("\n✅ All contracts are now deployed and configured!");
        console.log("🚀 Ready for Phase 2 development!");

    } catch (error) {
        console.error("❌ Deployment failed:", error.message);
        if (error.error && error.error.message) {
            console.error("Details:", error.error.message);
        }
        process.exit(1);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    }); 