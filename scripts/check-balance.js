const { ethers } = require("hardhat");

async function main() {
    console.log("🔍 ChaosChain DVN - Balance & Gas Estimation Check");
    console.log("=".repeat(50));

    // Get deployer account
    const [deployer] = await ethers.getSigners();
    console.log("📋 Deployer account:", deployer.address);

    // Check balance
    const balance = await deployer.getBalance();
    const balanceInEth = ethers.utils.formatEther(balance);
    console.log("💰 Current balance:", balanceInEth, "ETH");

    // Get network info
    const network = await ethers.provider.getNetwork();
    console.log("🌐 Network:", network.name, "(Chain ID:", network.chainId + ")");

    // Get current gas price
    const gasPrice = await ethers.provider.getGasPrice();
    const gasPriceInGwei = ethers.utils.formatUnits(gasPrice, "gwei");
    console.log("⛽ Current gas price:", gasPriceInGwei, "gwei");

    console.log("\n🏗️ Estimating deployment costs for remaining contract...");

    try {
        // Get contract factory for StudioPOC (the one that failed)
        const StudioPOC = await ethers.getContractFactory("StudioPOC");
        
        // StudioPOC requires DVN Registry address - use a dummy address for estimation
        const dummyAddress = "0x5A6207a71c49037316aD1C37E26df2E40aB599fE"; // Previously deployed DVNRegistry
        
        // Estimate deployment gas
        const deployTx = StudioPOC.getDeployTransaction(dummyAddress);
        const estimatedGas = await ethers.provider.estimateGas(deployTx);
        
        console.log("📊 StudioPOC estimated gas:", estimatedGas.toString());
        
        // Calculate cost
        const estimatedCost = gasPrice.mul(estimatedGas);
        const estimatedCostInEth = ethers.utils.formatEther(estimatedCost);
        
        console.log("💸 Estimated deployment cost:", estimatedCostInEth, "ETH");
        
        // Check if we have enough balance
        const hasEnoughBalance = balance.gt(estimatedCost.mul(120).div(100)); // 20% buffer
        console.log("✅ Sufficient balance:", hasEnoughBalance ? "Yes" : "No");
        
        if (!hasEnoughBalance) {
            const needed = estimatedCost.mul(120).div(100).sub(balance);
            const neededInEth = ethers.utils.formatEther(needed);
            console.log("⚠️  Additional ETH needed:", neededInEth, "ETH");
        }

        // Also estimate costs for configuration transactions
        const configGas = ethers.BigNumber.from("200000"); // Estimated gas for configuration calls
        const configCost = gasPrice.mul(configGas).mul(3); // 3 configuration calls
        const configCostInEth = ethers.utils.formatEther(configCost);
        
        console.log("\n🔧 Configuration transactions:");
        console.log("📊 Estimated gas per config call:", configGas.toString());
        console.log("💸 Total configuration cost:", configCostInEth, "ETH");
        
        const totalCost = estimatedCost.add(configCost);
        const totalCostInEth = ethers.utils.formatEther(totalCost);
        console.log("\n💰 Total estimated cost:", totalCostInEth, "ETH");
        
        const totalWithBuffer = totalCost.mul(120).div(100);
        const totalHasBalance = balance.gt(totalWithBuffer);
        console.log("✅ Can complete full deployment:", totalHasBalance ? "Yes" : "No");

    } catch (error) {
        console.error("❌ Error estimating deployment costs:", error.message);
    }

    console.log("\n" + "=".repeat(50));
    console.log("💡 Tip: If balance is low, get more Sepolia ETH from faucets:");
    console.log("   • https://sepoliafaucet.com/");
    console.log("   • https://www.alchemy.com/faucets/ethereum-sepolia");
    console.log("=".repeat(50));
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    }); 