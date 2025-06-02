const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DVNRegistryPOC", function () {
    let dvnRegistry;
    let owner, verifier1, verifier2, worker1, worker2;

    beforeEach(async function () {
        [owner, verifier1, verifier2, worker1, worker2] = await ethers.getSigners();
        
        const DVNRegistry = await ethers.getContractFactory("DVNRegistryPOC");
        dvnRegistry = await DVNRegistry.deploy();
        await dvnRegistry.deployed();
    });

    describe("Agent Registration", function () {
        it("Should register a verifier agent successfully", async function () {
            const agentId = ethers.utils.formatBytes32String("verifier-001");
            const endpoint = "https://va1.example.com";

            await expect(
                dvnRegistry.connect(verifier1).registerAgent(agentId, 1, endpoint) // AgentType.VERIFIER = 1
            ).to.emit(dvnRegistry, "AgentRegistered")
             .withArgs(verifier1.address, agentId, 1);

            const verifierInfo = await dvnRegistry.getVerifierAgent(verifier1.address);
            expect(verifierInfo.agentId).to.equal(agentId);
            expect(verifierInfo.isActive).to.be.true;
            expect(verifierInfo.reputation).to.equal(100); // INITIAL_REPUTATION
        });

        it("Should register a worker agent successfully", async function () {
            const agentId = ethers.utils.formatBytes32String("worker-001");

            await expect(
                dvnRegistry.connect(worker1).registerAgent(agentId, 0, "") // AgentType.WORKER = 0
            ).to.emit(dvnRegistry, "AgentRegistered")
             .withArgs(worker1.address, agentId, 0);

            const workerInfo = await dvnRegistry.getWorkerAgent(worker1.address);
            expect(workerInfo.agentId).to.equal(agentId);
            expect(workerInfo.isActive).to.be.true;
            expect(workerInfo.submissionCount).to.equal(0);
        });

        it("Should not allow duplicate agent registration", async function () {
            const agentId = ethers.utils.formatBytes32String("verifier-001");
            
            await dvnRegistry.connect(verifier1).registerAgent(agentId, 1, "");
            
            await expect(
                dvnRegistry.connect(verifier2).registerAgent(agentId, 1, "")
            ).to.be.revertedWith("Agent ID already exists");
        });

        it("Should not allow same address to register twice", async function () {
            const agentId1 = ethers.utils.formatBytes32String("verifier-001");
            const agentId2 = ethers.utils.formatBytes32String("verifier-002");
            
            await dvnRegistry.connect(verifier1).registerAgent(agentId1, 1, "");
            
            await expect(
                dvnRegistry.connect(verifier1).registerAgent(agentId2, 1, "")
            ).to.be.revertedWith("Address already registered");
        });

        it("Should not allow invalid agent ID", async function () {
            const invalidAgentId = ethers.constants.HashZero;
            
            await expect(
                dvnRegistry.connect(verifier1).registerAgent(invalidAgentId, 1, "")
            ).to.be.revertedWith("Invalid agent ID");
        });
    });

    describe("Staking", function () {
        beforeEach(async function () {
            const agentId = ethers.utils.formatBytes32String("verifier-001");
            await dvnRegistry.connect(verifier1).registerAgent(agentId, 1, "");
        });

        it("Should allow verifier to stake ETH", async function () {
            const stakeAmount = ethers.utils.parseEther("0.01");

            await expect(
                dvnRegistry.connect(verifier1).mockStake({ value: stakeAmount })
            ).to.emit(dvnRegistry, "VAStaked")
             .withArgs(verifier1.address, stakeAmount, stakeAmount);

            const verifierInfo = await dvnRegistry.getVerifierAgent(verifier1.address);
            expect(verifierInfo.stakedAmount).to.equal(stakeAmount);
        });

        it("Should not allow staking below minimum", async function () {
            const insufficientStake = ethers.utils.parseEther("0.0001");

            await expect(
                dvnRegistry.connect(verifier1).mockStake({ value: insufficientStake })
            ).to.be.revertedWith("Insufficient stake amount");
        });

        it("Should not allow non-verifier to stake", async function () {
            const stakeAmount = ethers.utils.parseEther("0.01");

            await expect(
                dvnRegistry.connect(worker1).mockStake({ value: stakeAmount })
            ).to.be.revertedWith("Not a registered verifier");
        });

        it("Should allow unstaking", async function () {
            const stakeAmount = ethers.utils.parseEther("0.01");
            const unstakeAmount = ethers.utils.parseEther("0.005");

            // First stake
            await dvnRegistry.connect(verifier1).mockStake({ value: stakeAmount });

            // Then unstake partially
            await expect(
                dvnRegistry.connect(verifier1).unstake(unstakeAmount)
            ).to.emit(dvnRegistry, "VAUnstaked")
             .withArgs(verifier1.address, unstakeAmount, stakeAmount.sub(unstakeAmount));
        });
    });

    describe("View Functions", function () {
        beforeEach(async function () {
            // Register some agents for testing
            await dvnRegistry.connect(verifier1).registerAgent(
                ethers.utils.formatBytes32String("verifier-001"), 1, ""
            );
            await dvnRegistry.connect(verifier2).registerAgent(
                ethers.utils.formatBytes32String("verifier-002"), 1, ""
            );
            await dvnRegistry.connect(worker1).registerAgent(
                ethers.utils.formatBytes32String("worker-001"), 0, ""
            );
        });

        it("Should return correct registration status", async function () {
            expect(await dvnRegistry.isRegisteredAgent(verifier1.address)).to.be.true;
            expect(await dvnRegistry.isRegisteredVerifier(verifier1.address)).to.be.true;
            expect(await dvnRegistry.isRegisteredWorker(verifier1.address)).to.be.false;

            expect(await dvnRegistry.isRegisteredAgent(worker1.address)).to.be.true;
            expect(await dvnRegistry.isRegisteredVerifier(worker1.address)).to.be.false;
            expect(await dvnRegistry.isRegisteredWorker(worker1.address)).to.be.true;

            expect(await dvnRegistry.isRegisteredAgent(worker2.address)).to.be.false;
        });

        it("Should return correct totals", async function () {
            expect(await dvnRegistry.totalRegisteredVAs()).to.equal(2);
            expect(await dvnRegistry.totalRegisteredWAs()).to.equal(1);
        });

        it("Should return all verifiers and workers", async function () {
            const allVerifiers = await dvnRegistry.getAllVerifiers();
            const allWorkers = await dvnRegistry.getAllWorkers();

            expect(allVerifiers.length).to.equal(2);
            expect(allWorkers.length).to.equal(1);
            expect(allVerifiers).to.include(verifier1.address);
            expect(allVerifiers).to.include(verifier2.address);
            expect(allWorkers).to.include(worker1.address);
        });

        it("Should calculate verifier weight correctly", async function () {
            const stakeAmount = ethers.utils.parseEther("0.01");
            await dvnRegistry.connect(verifier1).mockStake({ value: stakeAmount });

            const weight = await dvnRegistry.getVerifierWeight(verifier1.address);
            const expectedWeight = stakeAmount.mul(100); // stake * reputation (100)
            expect(weight).to.equal(expectedWeight);
        });

        it("Should return zero weight for unstaked verifier", async function () {
            const weight = await dvnRegistry.getVerifierWeight(verifier1.address);
            expect(weight).to.equal(0);
        });
    });

    describe("Constants", function () {
        it("Should have correct constants", async function () {
            expect(await dvnRegistry.MINIMUM_STAKE()).to.equal(ethers.utils.parseEther("0.001"));
            expect(await dvnRegistry.INITIAL_REPUTATION()).to.equal(100);
            expect(await dvnRegistry.MAX_REPUTATION()).to.equal(1000);
        });
    });
}); 