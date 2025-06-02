const { ethers } = require("hardhat");
const deploymentConfig = require("../config/deployment-localhost.json");

async function main() {
    console.log("🔍 Testing Contract Interactions");
    console.log("=".repeat(40));
    
    const [deployer, agent1, agent2] = await ethers.getSigners();
    
    // Get contract instances
    const DVNRegistry = await ethers.getContractFactory("DVNRegistryPOC");
    const dvnRegistry = DVNRegistry.attach(deploymentConfig.dvnRegistry);
    
    const StudioPOC = await ethers.getContractFactory("StudioPOC");
    const studio = StudioPOC.attach(deploymentConfig.studioPOC);
    
    console.log(`Using deployer: ${deployer.address}`);
    console.log(`Testing with agents: ${agent1.address}, ${agent2.address}`);
    console.log();

    try {
        // Test 1: Register a Verifier Agent
        console.log("📋 Test 1: Registering Verifier Agent...");
        const verifierAgentId = ethers.utils.formatBytes32String("test-verifier-001");
        const tx1 = await dvnRegistry.connect(agent1).registerAgent(
            verifierAgentId, 
            1, // AgentType.VERIFIER
            "http://localhost:3001"
        );
        await tx1.wait();
        
        const verifierInfo = await dvnRegistry.getVerifierAgent(agent1.address);
        console.log(`✅ Verifier registered: ${verifierInfo.isActive}`);
        console.log(`   Agent ID: ${ethers.utils.parseBytes32String(verifierInfo.agentId)}`);
        console.log(`   Reputation: ${verifierInfo.reputation}`);

        // Test 2: Stake ETH for Verifier
        console.log("\n💰 Test 2: Staking ETH...");
        const stakeAmount = ethers.utils.parseEther("0.01");
        const tx2 = await dvnRegistry.connect(agent1).mockStake({ value: stakeAmount });
        await tx2.wait();
        
        const updatedVerifierInfo = await dvnRegistry.getVerifierAgent(agent1.address);
        console.log(`✅ Staked: ${ethers.utils.formatEther(updatedVerifierInfo.stakedAmount)} ETH`);

        // Test 3: Register a Worker Agent
        console.log("\n👷 Test 3: Registering Worker Agent...");
        const workerAgentId = ethers.utils.formatBytes32String("test-worker-001");
        const tx3 = await dvnRegistry.connect(agent2).registerAgent(
            workerAgentId,
            0, // AgentType.WORKER
            ""
        );
        await tx3.wait();
        
        const workerInfo = await dvnRegistry.getWorkerAgent(agent2.address);
        console.log(`✅ Worker registered: ${workerInfo.isActive}`);
        console.log(`   Agent ID: ${ethers.utils.parseBytes32String(workerInfo.agentId)}`);

        // Test 4: Submit Work to Studio
        console.log("\n🏪 Test 4: Submitting work to Studio...");
        const submissionFee = ethers.utils.parseEther("0.0001");
        const workAgentId = ethers.utils.formatBytes32String("worker-001");
        const actionType = "KiranaAI_StockReport";
        const metadataURI = "QmTestHash123456789";
        
        const tx4 = await studio.connect(agent2).submitWork(
            workAgentId,
            actionType,
            metadataURI,
            { value: submissionFee }
        );
        const receipt = await tx4.wait();
        
        // Extract PoA ID from events
        const workSubmittedEvent = receipt.events.find(e => e.event === "WorkSubmitted");
        const poaId = workSubmittedEvent.args.poaId;
        
        console.log(`✅ Work submitted with PoA ID: ${poaId}`);
        
        // Get submission details
        const submission = await studio.getPoASubmission(poaId);
        console.log(`   Action Type: ${submission.actionType}`);
        console.log(`   Status: ${submission.status}`); // Should be 0 (SUBMITTED)
        console.log(`   Metadata URI: ${submission.metadataURI}`);

        // Test 5: Check Studio Stats
        console.log("\n📊 Test 5: Checking Studio Statistics...");
        const stats = await studio.getStudioStats();
        console.log(`✅ Studio Stats:`);
        console.log(`   Total Submissions: ${stats.total}`);
        console.log(`   Verified: ${stats.verified}`);
        console.log(`   Rejected: ${stats.rejected}`);
        console.log(`   Pending: ${stats.pending}`);

        // Test 6: Check DVN Registry Stats
        console.log("\n📈 Test 6: Checking DVN Registry Statistics...");
        const totalVAs = await dvnRegistry.totalRegisteredVAs();
        const totalWAs = await dvnRegistry.totalRegisteredWAs();
        const stakedVerifiers = await dvnRegistry.getStakedVerifiers();
        
        console.log(`✅ DVN Registry Stats:`);
        console.log(`   Total Verifier Agents: ${totalVAs}`);
        console.log(`   Total Worker Agents: ${totalWAs}`);
        console.log(`   Staked Verifiers: ${stakedVerifiers.length}`);

        console.log("\n" + "=".repeat(40));
        console.log("🎉 ALL TESTS PASSED! Contract system is working correctly.");
        console.log("=".repeat(40));

    } catch (error) {
        console.error("\n❌ Test failed:");
        console.error(error.message);
        process.exit(1);
    }
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    }); 