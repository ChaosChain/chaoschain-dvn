const { ethers } = require("hardhat");

async function main() {
    console.log("🏪 ChaosChain DVN PoC - Deploy StudioPOC Only");
    console.log("=".repeat(50));

    const [deployer] = await ethers.getSigners();
    console.log("Deploying with account:", deployer.address);
    
    const balance = await deployer.getBalance();
    console.log("Account balance:", ethers.utils.formatEther(balance), "ETH");
    
    const network = await ethers.provider.getNetwork();
    console.log("Network:", network.name);

    // Previously deployed DVN Registry address
    const dvnRegistryAddress = "0x5A6207a71c49037316aD1C37E26df2E40aB599fE";

    try {
        console.log("\n🏪 Deploying StudioPOC (KiranaAI)...");
        
        const StudioPOC = await ethers.getContractFactory("StudioPOC");
        const studio = await StudioPOC.deploy(dvnRegistryAddress);
        await studio.deployed();
        
        console.log("✅ StudioPOC deployed to:", studio.address);

        const deploymentData = {
            network: network.name,
            chainId: network.chainId,
            deployer: deployer.address,
            timestamp: new Date().toISOString(),
            contracts: {
                DVNRegistryPOC: "0x5A6207a71c49037316aD1C37E26df2E40aB599fE",
                DVNAttestationPOC: "0x950B75d0769dfC164f030976cEAd4C89BCA5541F",
                DVNConsensusPOC: "0x33807533035915AA6A461E4d0c7b136Ea0771dDa",
                StudioPOC: studio.address
            }
        };

        console.log("\n" + "=".repeat(50));
        console.log("🎉 STUDIO DEPLOYMENT COMPLETED!");
        console.log("=".repeat(50));

        console.log("\n📋 All Contract Addresses:");
        for (const [name, address] of Object.entries(deploymentData.contracts)) {
            console.log(`   ${name}: ${address}`);
        }
        
        console.log("\n🔗 Sepolia Etherscan Links:");
        for (const [name, address] of Object.entries(deploymentData.contracts)) {
            console.log(`   ${name}: https://sepolia.etherscan.io/address/${address}`);
        }

        console.log("\n⚠️  Note: Configuration still needed. Run configuration script separately.");
        console.log("✅ StudioPOC deployment successful!");

    } catch (error) {
        console.error("❌ Deployment failed:", error.message);
        process.exit(1);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    }); 