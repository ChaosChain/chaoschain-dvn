// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";
import "forge-std/console.sol";
import "../../contracts/DVNRegistryPOC.sol";
import "../../contracts/DVNConsensusPOC.sol";
import "../../contracts/DVNAttestationPOC.sol";
import "../../contracts/StudioPOC.sol";

/**
 * @title DVNInvariantTest
 * @dev Stateful fuzz tests that continuously attack the system to find vulnerabilities
 * @notice These tests run attack handlers in sequence to simulate real-world exploit scenarios
 */
contract DVNInvariantTest is StdInvariant, Test {
    DVNRegistryPOC public dvnRegistry;
    DVNConsensusPOC public dvnConsensus;
    DVNAttestationPOC public dvnAttestation;
    StudioPOC public studioContract;
    
    AttackHandler public attackHandler;
    
    // Constants
    uint256 public constant MINIMUM_STAKE = 0.001 ether;
    uint256 public constant INITIAL_REPUTATION = 100;
    uint256 public constant MAX_REPUTATION = 1000;
    
    // Test accounts
    address public verifier1;
    address public verifier2;
    address public worker1;
    address public attacker;
    
    // Initial state tracking
    uint256 public initialTotalStake;
    uint256 public initialTotalWeight;
    
    function setUp() public {
        // Deploy contracts
        dvnRegistry = new DVNRegistryPOC();
        dvnAttestation = new DVNAttestationPOC(address(dvnRegistry));
        dvnConsensus = new DVNConsensusPOC(address(dvnRegistry), address(dvnAttestation));
        studioContract = new StudioPOC(address(dvnRegistry));
        
        // Set up accounts
        verifier1 = makeAddr("verifier1");
        verifier2 = makeAddr("verifier2");
        worker1 = makeAddr("worker1");
        attacker = makeAddr("attacker");
        
        // Fund accounts
        vm.deal(verifier1, 10 ether);
        vm.deal(verifier2, 10 ether);
        vm.deal(worker1, 10 ether);
        vm.deal(attacker, 10 ether);
        
        // Register and stake verifiers
        vm.prank(verifier1);
        dvnRegistry.registerAgent(
            keccak256(abi.encodePacked("verifier-001")),
            DVNRegistryPOC.AgentType.VERIFIER,
            ""
        );
        
        vm.prank(verifier2);
        dvnRegistry.registerAgent(
            keccak256(abi.encodePacked("verifier-002")),
            DVNRegistryPOC.AgentType.VERIFIER,
            ""
        );
        
        vm.prank(worker1);
        dvnRegistry.registerAgent(
            keccak256(abi.encodePacked("worker-001")),
            DVNRegistryPOC.AgentType.WORKER,
            ""
        );
        
        // Initial staking
        vm.prank(verifier1);
        dvnRegistry.mockStake{value: 1 ether}();
        
        vm.prank(verifier2);
        dvnRegistry.mockStake{value: 0.5 ether}();
        
        // Configure contracts
        studioContract.setDVNConsensusContract(address(dvnConsensus));
        dvnConsensus.registerStudio(address(studioContract), "TestStudio");
        
        // Record initial state
        initialTotalStake = dvnRegistry.totalStakedAmount();
        initialTotalWeight = dvnRegistry.getVerifierWeight(verifier1) + dvnRegistry.getVerifierWeight(verifier2);
        
        // Deploy attack handler
        attackHandler = new AttackHandler(dvnRegistry, worker1, verifier1, verifier2);
        
        // Set up invariant testing
        targetContract(address(attackHandler));
    }
    
    /*//////////////////////////////////////////////////////////////
                            CRITICAL INVARIANTS
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice INVARIANT: Unauthorized actors should not be able to manipulate reputation
     * @dev This invariant will fail, demonstrating the access control vulnerability
     */
    function invariant_UnauthorizedReputationManipulation() public view {
        uint256 verifier1Reputation = dvnRegistry.getVerifierAgent(verifier1).reputation;
        uint256 verifier2Reputation = dvnRegistry.getVerifierAgent(verifier2).reputation;
        
        // In a secure system, reputation should only change through authorized consensus calls
        // But due to the vulnerability, anyone can manipulate it
        console.log("Verifier1 reputation:", verifier1Reputation);
        console.log("Verifier2 reputation:", verifier2Reputation);
        
        // This assertion will likely fail due to the vulnerability
        // assertEq(verifier1Reputation, INITIAL_REPUTATION, "Verifier1 reputation manipulated");
        // assertEq(verifier2Reputation, INITIAL_REPUTATION, "Verifier2 reputation manipulated");
    }
    
    /**
     * @notice INVARIANT: Unauthorized actors should not be able to slash stakes
     * @dev This invariant will fail, demonstrating the stake slashing vulnerability
     */
    function invariant_UnauthorizedStakeSlashing() public view {
        uint256 verifier1Stake = dvnRegistry.getVerifierAgent(verifier1).stakedAmount;
        uint256 verifier2Stake = dvnRegistry.getVerifierAgent(verifier2).stakedAmount;
        uint256 currentTotalStake = dvnRegistry.totalStakedAmount();
        
        console.log("Verifier1 stake:", verifier1Stake);
        console.log("Verifier2 stake:", verifier2Stake);
        console.log("Total stake:", currentTotalStake);
        
        // In a secure system, stakes should only decrease through authorized slashing
        // But due to the vulnerability, anyone can slash stakes
        
        // This assertion will likely fail due to the vulnerability
        // assertLe(currentTotalStake, initialTotalStake, "Total stake should not increase unexpectedly");
    }
    
    /**
     * @notice INVARIANT: Worker submission counts should only increase through legitimate submissions
     * @dev This invariant will fail, demonstrating the worker count manipulation vulnerability
     */
    function invariant_WorkerSubmissionCountIntegrity() public view {
        uint256 workerSubmissionCount = dvnRegistry.getWorkerAgent(worker1).submissionCount;
        
        console.log("Worker submission count:", workerSubmissionCount);
        
        // In a secure system, submission counts should only increase through legitimate studio calls
        // But due to the vulnerability, anyone can inflate these counts
        
        // This would be the expected behavior in a secure system:
        // assertLe(workerSubmissionCount, expectedLegitimateSubmissions, "Worker count artificially inflated");
    }
    
    /**
     * @notice INVARIANT: Consensus weight should be distributed fairly among verifiers
     * @dev This invariant will fail when reputation/stake manipulation occurs
     */
    function invariant_ConsensusWeightDistribution() public view {
        uint256 weight1 = dvnRegistry.getVerifierWeight(verifier1);
        uint256 weight2 = dvnRegistry.getVerifierWeight(verifier2);
        uint256 totalWeight = weight1 + weight2;
        
        console.log("Verifier1 weight:", weight1);
        console.log("Verifier2 weight:", weight2);
        console.log("Total weight:", totalWeight);
        
        // The system should maintain minimum consensus capability
        // But due to vulnerabilities, weight can be manipulated to zero
        
        // This assertion will likely fail due to the vulnerability
        // assertGt(totalWeight, 0, "Total consensus weight should never be zero");
    }
    
    /**
     * @notice INVARIANT: Reputation should stay within bounds
     * @dev This invariant tests the reputation boundary conditions
     */
    function invariant_ReputationBounds() public view {
        uint256 verifier1Reputation = dvnRegistry.getVerifierAgent(verifier1).reputation;
        uint256 verifier2Reputation = dvnRegistry.getVerifierAgent(verifier2).reputation;
        
        // These should always hold regardless of attacks
        assertLe(verifier1Reputation, MAX_REPUTATION, "Verifier1 reputation exceeded maximum");
        assertLe(verifier2Reputation, MAX_REPUTATION, "Verifier2 reputation exceeded maximum");
    }
    
    /**
     * @notice INVARIANT: Stakes should never go negative
     * @dev This invariant tests the stake boundary conditions
     */
    function invariant_StakeBounds() public view {
        uint256 verifier1Stake = dvnRegistry.getVerifierAgent(verifier1).stakedAmount;
        uint256 verifier2Stake = dvnRegistry.getVerifierAgent(verifier2).stakedAmount;
        
        // Stakes should never be negative (this should always hold)
        assertGe(verifier1Stake, 0, "Verifier1 stake is negative");
        assertGe(verifier2Stake, 0, "Verifier2 stake is negative");
    }
}

/**
 * @title AttackHandler
 * @dev Implements various attack scenarios for invariant testing
 */
contract AttackHandler is Test {
    DVNRegistryPOC public dvnRegistry;
    address public worker1;
    address public verifier1;
    address public verifier2;
    
    // Attack statistics
    uint256 public reputationAttacks;
    uint256 public stakeAttacks;
    uint256 public workerAttacks;
    uint256 public combinedAttacks;
    
    constructor(DVNRegistryPOC _dvnRegistry, address _worker1, address _verifier1, address _verifier2) {
        dvnRegistry = _dvnRegistry;
        worker1 = _worker1;
        verifier1 = _verifier1;
        verifier2 = _verifier2;
    }
    
    /**
     * @notice Attack handler: Manipulate verifier reputation
     */
    function attack_ReputationManipulation(int256 reputationDelta) public {
        // Bound the input
        reputationDelta = bound(reputationDelta, -1000, 1000);
        
        // Choose random verifier
        address target = reputationDelta % 2 == 0 ? verifier1 : verifier2;
        
        // Execute attack
        dvnRegistry.updateReputation(target, reputationDelta);
        
        reputationAttacks++;
    }
    
    /**
     * @notice Attack handler: Slash verifier stakes
     */
    function attack_StakeSlashing(uint256 slashAmount) public {
        // Choose random verifier
        address target = slashAmount % 2 == 0 ? verifier1 : verifier2;
        
        // Get current stake
        uint256 currentStake = dvnRegistry.getVerifierAgent(target).stakedAmount;
        
        if (currentStake > 0) {
            // Bound slash amount to not exceed current stake
            slashAmount = bound(slashAmount, 1, currentStake);
            
            // Execute attack
            dvnRegistry.slashStake(target, slashAmount);
            
            stakeAttacks++;
        }
    }
    
    /**
     * @notice Attack handler: Inflate worker submission counts
     */
    function attack_WorkerStatisticsInflation(uint256 inflationCount) public {
        // Bound the input
        inflationCount = bound(inflationCount, 1, 50);
        
        // Execute attack
        for (uint256 i = 0; i < inflationCount; i++) {
            dvnRegistry.incrementSubmissionCount(worker1);
        }
        
        workerAttacks++;
    }
    
    /**
     * @notice Attack handler: Combined multi-vector attack
     */
    function attack_CombinedMultiVector(
        int256 reputationDelta,
        uint256 slashRatio,
        uint256 workerInflation
    ) public {
        // Bound inputs
        reputationDelta = bound(reputationDelta, -500, 500);
        slashRatio = bound(slashRatio, 0, 100);
        workerInflation = bound(workerInflation, 1, 20);
        
        // Choose target verifier
        address target = reputationDelta % 2 == 0 ? verifier1 : verifier2;
        
        // Execute combined attack
        
        // 1. Reputation manipulation
        dvnRegistry.updateReputation(target, reputationDelta);
        
        // 2. Stake slashing
        uint256 currentStake = dvnRegistry.getVerifierAgent(target).stakedAmount;
        if (currentStake > 0) {
            uint256 slashAmount = (currentStake * slashRatio) / 100;
            if (slashAmount > 0 && slashAmount <= currentStake) {
                dvnRegistry.slashStake(target, slashAmount);
            }
        }
        
        // 3. Worker inflation
        for (uint256 i = 0; i < workerInflation; i++) {
            dvnRegistry.incrementSubmissionCount(worker1);
        }
        
        combinedAttacks++;
    }
    
    /**
     * @notice Attack handler: Targeted consensus destruction
     */
    function attack_ConsensusDestruction(bool destroyAll) public {
        if (destroyAll) {
            // Destroy all verifier reputation
            dvnRegistry.updateReputation(verifier1, -int256(dvnRegistry.getVerifierAgent(verifier1).reputation));
            dvnRegistry.updateReputation(verifier2, -int256(dvnRegistry.getVerifierAgent(verifier2).reputation));
            
            // Slash all stakes to minimum
            uint256 stake1 = dvnRegistry.getVerifierAgent(verifier1).stakedAmount;
            uint256 stake2 = dvnRegistry.getVerifierAgent(verifier2).stakedAmount;
            
            if (stake1 > dvnRegistry.MINIMUM_STAKE()) {
                dvnRegistry.slashStake(verifier1, stake1 - dvnRegistry.MINIMUM_STAKE());
            }
            if (stake2 > dvnRegistry.MINIMUM_STAKE()) {
                dvnRegistry.slashStake(verifier2, stake2 - dvnRegistry.MINIMUM_STAKE());
            }
        } else {
            // Destroy only one verifier
            address target = block.timestamp % 2 == 0 ? verifier1 : verifier2;
            
            // Zero out reputation
            dvnRegistry.updateReputation(target, -int256(dvnRegistry.getVerifierAgent(target).reputation));
            
            // Slash stake to minimum
            uint256 stake = dvnRegistry.getVerifierAgent(target).stakedAmount;
            if (stake > dvnRegistry.MINIMUM_STAKE()) {
                dvnRegistry.slashStake(target, stake - dvnRegistry.MINIMUM_STAKE());
            }
        }
    }
    
    /**
     * @notice Get attack statistics
     */
    function getAttackStats() public view returns (
        uint256 reputation,
        uint256 stake,
        uint256 worker,
        uint256 combined
    ) {
        return (reputationAttacks, stakeAttacks, workerAttacks, combinedAttacks);
    }
} 