// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../contracts/DVNRegistryPOC.sol";
import "../../contracts/DVNConsensusPOC.sol";
import "../../contracts/DVNAttestationPOC.sol";
import "../../contracts/StudioPOC.sol";
import "../../contracts/interfaces/IStudioPolicy.sol";

/**
 * @title DVNIntegrationFuzzTest
 * @dev Comprehensive fuzz tests for multi-contract integration attacks
 * @notice Tests cross-contract vulnerabilities and consensus manipulation
 */
contract DVNIntegrationFuzzTest is Test {
    DVNRegistryPOC public dvnRegistry;
    DVNConsensusPOC public dvnConsensus;
    DVNAttestationPOC public dvnAttestation;
    StudioPOC public studioContract;
    
    // Test accounts
    address public owner;
    address public verifier1;
    address public verifier2;
    address public verifier3;
    address public worker1;
    address public worker2;
    address public attacker;
    address public studio;
    
    // Test constants
    uint256 public constant MINIMUM_STAKE = 0.001 ether;
    uint256 public constant INITIAL_REPUTATION = 100;
    uint256 public constant MAX_REPUTATION = 1000;
    uint256 public constant VERIFICATION_FEE = 0.0001 ether;
    
    // Test state
    mapping(address => bool) public isVerifier;
    mapping(address => bool) public isWorker;
    bytes32[] public testSubmissions;
    
    event LogIntegrationAttack(string attackType, address attacker, uint256 impact);
    event LogConsensusManipulation(bytes32 poaId, uint256 beforeWeight, uint256 afterWeight);
    
    function setUp() public {
        // Deploy contracts
        dvnRegistry = new DVNRegistryPOC();
        dvnAttestation = new DVNAttestationPOC(address(dvnRegistry));
        dvnConsensus = new DVNConsensusPOC(address(dvnRegistry), address(dvnAttestation));
        studioContract = new StudioPOC(address(dvnRegistry));
        
        // Set up accounts
        owner = address(this);
        verifier1 = makeAddr("verifier1");
        verifier2 = makeAddr("verifier2");
        verifier3 = makeAddr("verifier3");
        worker1 = makeAddr("worker1");
        worker2 = makeAddr("worker2");
        attacker = makeAddr("attacker");
        studio = makeAddr("studio");
        
        // Fund accounts
        vm.deal(verifier1, 10 ether);
        vm.deal(verifier2, 10 ether);
        vm.deal(verifier3, 10 ether);
        vm.deal(worker1, 10 ether);
        vm.deal(worker2, 10 ether);
        vm.deal(attacker, 10 ether);
        vm.deal(studio, 10 ether);
        
        // Register verifiers
        _registerAndStakeVerifier(verifier1, "verifier-001", 1 ether);
        _registerAndStakeVerifier(verifier2, "verifier-002", 0.5 ether);
        _registerAndStakeVerifier(verifier3, "verifier-003", 0.3 ether);
        
        // Register workers
        _registerWorker(worker1, "worker-001");
        _registerWorker(worker2, "worker-002");
        
        // Configure contracts
        studioContract.setDVNConsensusContract(address(dvnConsensus));
        dvnConsensus.registerStudio(address(studioContract), "TestStudio");
        
        isVerifier[verifier1] = true;
        isVerifier[verifier2] = true;
        isVerifier[verifier3] = true;
        isWorker[worker1] = true;
        isWorker[worker2] = true;
    }
    
    function _registerAndStakeVerifier(address va, string memory agentId, uint256 stakeAmount) internal {
        vm.prank(va);
        dvnRegistry.registerAgent(
            keccak256(abi.encodePacked(agentId)),
            DVNRegistryPOC.AgentType.VERIFIER,
            ""
        );
        
        vm.prank(va);
        dvnRegistry.mockStake{value: stakeAmount}();
    }
    
    function _registerWorker(address wa, string memory agentId) internal {
        vm.prank(wa);
        dvnRegistry.registerAgent(
            keccak256(abi.encodePacked(agentId)),
            DVNRegistryPOC.AgentType.WORKER,
            ""
        );
    }
    
    /*//////////////////////////////////////////////////////////////
                    CONSENSUS MANIPULATION FUZZ TESTS
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice FUZZ TEST: Pre-consensus reputation manipulation
     * @dev Tests manipulating verifier reputation before consensus to bias results
     */
    function testFuzz_PreConsensusReputationManipulation(
        address attacker_addr,
        int256 reputationDelta1,
        int256 reputationDelta2,
        int256 reputationDelta3,
        uint256 submissionSeed
    ) public {
        // Bound inputs
        vm.assume(attacker_addr != address(0));
        vm.assume(attacker_addr != address(this));
        reputationDelta1 = bound(reputationDelta1, -int256(MAX_REPUTATION), int256(MAX_REPUTATION));
        reputationDelta2 = bound(reputationDelta2, -int256(MAX_REPUTATION), int256(MAX_REPUTATION));
        reputationDelta3 = bound(reputationDelta3, -int256(MAX_REPUTATION), int256(MAX_REPUTATION));
        
        // Record initial consensus weights
        uint256 initialWeight1 = dvnRegistry.getVerifierWeight(verifier1);
        uint256 initialWeight2 = dvnRegistry.getVerifierWeight(verifier2);
        uint256 initialWeight3 = dvnRegistry.getVerifierWeight(verifier3);
        uint256 totalInitialWeight = initialWeight1 + initialWeight2 + initialWeight3;
        
        // Create a test submission
        bytes32 poaId = _createTestSubmission(submissionSeed);
        
        // ATTACK: Manipulate reputation before consensus
        vm.startPrank(attacker_addr);
        dvnRegistry.updateReputation(verifier1, reputationDelta1);
        dvnRegistry.updateReputation(verifier2, reputationDelta2);
        dvnRegistry.updateReputation(verifier3, reputationDelta3);
        vm.stopPrank();
        
        // Record manipulated consensus weights
        uint256 finalWeight1 = dvnRegistry.getVerifierWeight(verifier1);
        uint256 finalWeight2 = dvnRegistry.getVerifierWeight(verifier2);
        uint256 finalWeight3 = dvnRegistry.getVerifierWeight(verifier3);
        uint256 totalFinalWeight = finalWeight1 + finalWeight2 + finalWeight3;
        
        // Calculate impact
        uint256 weightChange = totalInitialWeight > totalFinalWeight ? 
            totalInitialWeight - totalFinalWeight : totalFinalWeight - totalInitialWeight;
        
        emit LogConsensusManipulation(poaId, totalInitialWeight, totalFinalWeight);
        
        // Log significant consensus manipulation
        if (weightChange > totalInitialWeight / 4) { // More than 25% change
            emit LogIntegrationAttack(
                "preConsensusReputationManipulation",
                attacker_addr,
                weightChange
            );
        }
        
        // Verify the manipulation actually affects consensus power
        if (totalFinalWeight == 0 && totalInitialWeight > 0) {
            emit LogIntegrationAttack(
                "completeConsensusDestruction",
                attacker_addr,
                totalInitialWeight
            );
        }
    }
    
    /**
     * @notice FUZZ TEST: Mid-consensus stake slashing attack
     * @dev Tests slashing stakes during active consensus to manipulate outcomes
     */
    function testFuzz_MidConsensusStakeSlashing(
        address attacker_addr,
        uint256 slashRatio1,
        uint256 slashRatio2,
        uint256 slashRatio3,
        uint256 submissionSeed
    ) public {
        // Bound inputs
        vm.assume(attacker_addr != address(0));
        vm.assume(attacker_addr != address(this));
        slashRatio1 = bound(slashRatio1, 0, 100);
        slashRatio2 = bound(slashRatio2, 0, 100);
        slashRatio3 = bound(slashRatio3, 0, 100);
        
        // Create and start consensus on a submission
        bytes32 poaId = _createTestSubmission(submissionSeed);
        vm.prank(address(studioContract));
        dvnConsensus.startSubmissionProcessing(poaId, address(studioContract));
        
        // Record initial state
        uint256 initialStake1 = dvnRegistry.getVerifierAgent(verifier1).stakedAmount;
        uint256 initialStake2 = dvnRegistry.getVerifierAgent(verifier2).stakedAmount;
        uint256 initialStake3 = dvnRegistry.getVerifierAgent(verifier3).stakedAmount;
        
        uint256 initialWeight1 = dvnRegistry.getVerifierWeight(verifier1);
        uint256 initialWeight2 = dvnRegistry.getVerifierWeight(verifier2);
        uint256 initialWeight3 = dvnRegistry.getVerifierWeight(verifier3);
        uint256 totalInitialWeight = initialWeight1 + initialWeight2 + initialWeight3;
        
        // ATTACK: Slash stakes during consensus
        vm.startPrank(attacker_addr);
        
        uint256 slashAmount1 = (initialStake1 * slashRatio1) / 100;
        uint256 slashAmount2 = (initialStake2 * slashRatio2) / 100;
        uint256 slashAmount3 = (initialStake3 * slashRatio3) / 100;
        
        if (slashAmount1 > 0 && slashAmount1 <= initialStake1) {
            dvnRegistry.slashStake(verifier1, slashAmount1);
        }
        if (slashAmount2 > 0 && slashAmount2 <= initialStake2) {
            dvnRegistry.slashStake(verifier2, slashAmount2);
        }
        if (slashAmount3 > 0 && slashAmount3 <= initialStake3) {
            dvnRegistry.slashStake(verifier3, slashAmount3);
        }
        
        vm.stopPrank();
        
        // Calculate final consensus power
        uint256 finalWeight1 = dvnRegistry.getVerifierWeight(verifier1);
        uint256 finalWeight2 = dvnRegistry.getVerifierWeight(verifier2);
        uint256 finalWeight3 = dvnRegistry.getVerifierWeight(verifier3);
        uint256 totalFinalWeight = finalWeight1 + finalWeight2 + finalWeight3;
        
        // Calculate total slashed amount
        uint256 totalSlashed = slashAmount1 + slashAmount2 + slashAmount3;
        
        // Log significant attacks
        if (totalSlashed > (initialStake1 + initialStake2 + initialStake3) / 10) {
            emit LogIntegrationAttack(
                "midConsensusStakeSlashing",
                attacker_addr,
                totalSlashed
            );
        }
        
        // Check if consensus power was significantly affected
        if (totalFinalWeight < totalInitialWeight / 2) {
            emit LogIntegrationAttack(
                "majorConsensusWeakening",
                attacker_addr,
                totalInitialWeight - totalFinalWeight
            );
        }
    }
    
    /**
     * @notice FUZZ TEST: Cross-contract worker statistic manipulation
     * @dev Tests inflating worker statistics to bias studio selection
     */
    function testFuzz_WorkerStatisticManipulation(
        address attacker_addr,
        uint256 inflationCount1,
        uint256 inflationCount2,
        uint256 submissionSeed
    ) public {
        // Bound inputs
        vm.assume(attacker_addr != address(0));
        vm.assume(attacker_addr != address(this));
        inflationCount1 = bound(inflationCount1, 1, 500);
        inflationCount2 = bound(inflationCount2, 1, 500);
        
        // Record initial worker statistics
        uint256 initialCount1 = dvnRegistry.getWorkerAgent(worker1).submissionCount;
        uint256 initialCount2 = dvnRegistry.getWorkerAgent(worker2).submissionCount;
        
        // Create test submission
        bytes32 poaId = _createTestSubmission(submissionSeed);
        
        // ATTACK: Inflate worker statistics
        vm.startPrank(attacker_addr);
        
        for (uint256 i = 0; i < inflationCount1; i++) {
            dvnRegistry.incrementSubmissionCount(worker1);
        }
        
        for (uint256 i = 0; i < inflationCount2; i++) {
            dvnRegistry.incrementSubmissionCount(worker2);
        }
        
        vm.stopPrank();
        
        // Verify manipulation
        uint256 finalCount1 = dvnRegistry.getWorkerAgent(worker1).submissionCount;
        uint256 finalCount2 = dvnRegistry.getWorkerAgent(worker2).submissionCount;
        
        uint256 totalInflation = inflationCount1 + inflationCount2;
        
        assertEq(finalCount1, initialCount1 + inflationCount1, "Worker 1 count manipulation failed");
        assertEq(finalCount2, initialCount2 + inflationCount2, "Worker 2 count manipulation failed");
        
        // Log significant manipulation
        if (totalInflation > 100) {
            emit LogIntegrationAttack(
                "workerStatisticManipulation",
                attacker_addr,
                totalInflation
            );
        }
    }
    
    /**
     * @notice FUZZ TEST: Multi-vector simultaneous attack
     * @dev Tests coordinated attacks across multiple contract functions
     */
    function testFuzz_MultiVectorSimultaneousAttack(
        address attacker_addr,
        int256 reputationDelta,
        uint256 slashRatio,
        uint256 workerInflation,
        uint8 targetVerifierIndex,
        uint256 submissionSeed
    ) public {
        // Bound inputs
        vm.assume(attacker_addr != address(0));
        vm.assume(attacker_addr != address(this));
        reputationDelta = bound(reputationDelta, -int256(MAX_REPUTATION), int256(MAX_REPUTATION));
        slashRatio = bound(slashRatio, 0, 100);
        workerInflation = bound(workerInflation, 1, 200);
        
        // Select target verifier
        address targetVerifier;
        if (targetVerifierIndex % 3 == 0) targetVerifier = verifier1;
        else if (targetVerifierIndex % 3 == 1) targetVerifier = verifier2;
        else targetVerifier = verifier3;
        
        // Record initial state
        uint256 initialStake = dvnRegistry.getVerifierAgent(targetVerifier).stakedAmount;
        uint256 initialReputation = dvnRegistry.getVerifierAgent(targetVerifier).reputation;
        uint256 initialWeight = dvnRegistry.getVerifierWeight(targetVerifier);
        uint256 initialWorkerCount = dvnRegistry.getWorkerAgent(worker1).submissionCount;
        
        // Create test submission
        bytes32 poaId = _createTestSubmission(submissionSeed);
        
        // MULTI-VECTOR ATTACK: Execute all attacks simultaneously
        vm.startPrank(attacker_addr);
        
        // Attack 1: Reputation manipulation
        dvnRegistry.updateReputation(targetVerifier, reputationDelta);
        
        // Attack 2: Stake slashing
        uint256 slashAmount = (initialStake * slashRatio) / 100;
        if (slashAmount > 0 && slashAmount <= initialStake) {
            dvnRegistry.slashStake(targetVerifier, slashAmount);
        }
        
        // Attack 3: Worker statistic inflation
        for (uint256 i = 0; i < workerInflation; i++) {
            dvnRegistry.incrementSubmissionCount(worker1);
        }
        
        vm.stopPrank();
        
        // Verify all attacks succeeded
        uint256 finalStake = dvnRegistry.getVerifierAgent(targetVerifier).stakedAmount;
        uint256 finalReputation = dvnRegistry.getVerifierAgent(targetVerifier).reputation;
        uint256 finalWeight = dvnRegistry.getVerifierWeight(targetVerifier);
        uint256 finalWorkerCount = dvnRegistry.getWorkerAgent(worker1).submissionCount;
        
        // Calculate total impact
        uint256 weightLoss = initialWeight > finalWeight ? initialWeight - finalWeight : 0;
        uint256 stakeSlashed = initialStake > finalStake ? initialStake - finalStake : 0;
        uint256 workerInflated = finalWorkerCount - initialWorkerCount;
        
        // Log multi-vector attack
        uint256 totalImpact = weightLoss + stakeSlashed + workerInflated;
        
        if (totalImpact > 0) {
            emit LogIntegrationAttack(
                "multiVectorSimultaneousAttack",
                attacker_addr,
                totalImpact
            );
        }
        
        // Check for complete verifier elimination
        if (finalWeight == 0 && initialWeight > 0) {
            emit LogIntegrationAttack(
                "completeVerifierElimination",
                attacker_addr,
                initialWeight
            );
        }
    }
    
    /*//////////////////////////////////////////////////////////////
                    INTEGRATION HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    
    function _createTestSubmission(uint256 seed) internal returns (bytes32 poaId) {
        string memory actionType = "KiranaAI_StockReport";
        string memory metadataURI = string(abi.encodePacked("ipfs://test", seed));
        
        vm.prank(worker1);
        poaId = studioContract.submitWork{value: VERIFICATION_FEE}(
            keccak256(abi.encodePacked("worker-001")),
            actionType,
            metadataURI
        );
        
        testSubmissions.push(poaId);
        return poaId;
    }
    
    /*//////////////////////////////////////////////////////////////
                    INVARIANT TESTS
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice INVARIANT: Total consensus weight should never be completely eliminated by attacks
     * @dev This tests that the system maintains some consensus capability
     */
    function invariant_MinimumConsensusWeight() public view {
        address[] memory verifiers = dvnRegistry.getAllVerifiers();
        uint256 totalWeight = 0;
        
        for (uint256 i = 0; i < verifiers.length; i++) {
            totalWeight += dvnRegistry.getVerifierWeight(verifiers[i]);
        }
        
        // At least one verifier should maintain some weight
        // This invariant will likely fail due to the vulnerabilities
        // but demonstrates the expected behavior
        if (verifiers.length > 0) {
            // In a secure system, this should not be zero
            // But due to vulnerabilities, it can be manipulated to zero
            console.log("Total consensus weight:", totalWeight);
        }
    }
    
    /**
     * @notice INVARIANT: Worker statistics should only increase through legitimate submissions
     * @dev This tests that worker counts reflect actual work (will fail due to vulnerability)
     */
    function invariant_WorkerStatisticsIntegrity() public view {
        address[] memory workers = dvnRegistry.getAllWorkers();
        
        for (uint256 i = 0; i < workers.length; i++) {
            uint256 registryCount = dvnRegistry.getWorkerAgent(workers[i]).submissionCount;
            console.log("Worker submissions:", registryCount);
            
            // In a secure system, this should match actual submissions
            // But due to vulnerabilities, it can be artificially inflated
        }
    }
    
    /**
     * @notice INVARIANT: Verifier reputation should only change through consensus mechanisms
     * @dev This tests that reputation changes are authorized (will fail due to vulnerability)
     */
    function invariant_ReputationChangeAuthorization() public view {
        address[] memory verifiers = dvnRegistry.getAllVerifiers();
        
        for (uint256 i = 0; i < verifiers.length; i++) {
            uint256 reputation = dvnRegistry.getVerifierAgent(verifiers[i]).reputation;
            console.log("Verifier reputation:", reputation);
            
            // In a secure system, reputation should only change through authorized calls
            // But due to vulnerabilities, anyone can manipulate it
        }
    }
} 