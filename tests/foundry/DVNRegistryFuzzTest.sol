// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../contracts/DVNRegistryPOC.sol";

/**
 * @title DVNRegistryFuzzTest
 * @dev Comprehensive fuzz tests for DVN Registry contract based on audit findings
 * @notice These tests validate the security vulnerabilities identified in the audit report
 */
contract DVNRegistryFuzzTest is Test {
    DVNRegistryPOC public dvnRegistry;
    
    // Test accounts
    address public owner;
    address public verifier1;
    address public verifier2;
    address public worker1;
    address public attacker;
    address[] public attackers;
    
    // Constants from contract
    uint256 public constant MINIMUM_STAKE = 0.001 ether;
    uint256 public constant INITIAL_REPUTATION = 100;
    uint256 public constant MAX_REPUTATION = 1000;
    
    // Test state tracking
    mapping(address => bool) public registeredVerifiers;
    mapping(address => bool) public registeredWorkers;
    mapping(address => uint256) public verifierStakes;
    mapping(address => uint256) public verifierReputations;
    
    event LogFuzzInput(string testName, address actor, uint256 value, int256 delta);
    event LogVulnerabilityFound(string vulnerability, address attacker, uint256 impact);
    
    function setUp() public {
        // Deploy contract
        dvnRegistry = new DVNRegistryPOC();
        
        // Set up test accounts
        owner = address(this);
        verifier1 = makeAddr("verifier1");
        verifier2 = makeAddr("verifier2");
        worker1 = makeAddr("worker1");
        attacker = makeAddr("attacker");
        
        // Create multiple attacker accounts for advanced testing
        for (uint i = 0; i < 10; i++) {
            attackers.push(makeAddr(string(abi.encodePacked("attacker", i))));
        }
        
        // Fund accounts
        vm.deal(verifier1, 10 ether);
        vm.deal(verifier2, 10 ether);
        vm.deal(worker1, 10 ether);
        vm.deal(attacker, 10 ether);
        
        for (uint i = 0; i < attackers.length; i++) {
            vm.deal(attackers[i], 10 ether);
        }
        
        // Register initial agents
        _registerVerifier(verifier1, "verifier-001");
        _registerVerifier(verifier2, "verifier-002");
        _registerWorker(worker1, "worker-001");
        
        // Initial staking
        vm.prank(verifier1);
        dvnRegistry.mockStake{value: 1 ether}();
        verifierStakes[verifier1] = 1 ether;
        verifierReputations[verifier1] = INITIAL_REPUTATION;
        
        vm.prank(verifier2);
        dvnRegistry.mockStake{value: 0.5 ether}();
        verifierStakes[verifier2] = 0.5 ether;
        verifierReputations[verifier2] = INITIAL_REPUTATION;
        
        registeredVerifiers[verifier1] = true;
        registeredVerifiers[verifier2] = true;
        registeredWorkers[worker1] = true;
    }
    
    function _registerVerifier(address va, string memory agentId) internal {
        vm.prank(va);
        dvnRegistry.registerAgent(
            keccak256(abi.encodePacked(agentId)),
            DVNRegistryPOC.AgentType.VERIFIER,
            ""
        );
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
                        CRITICAL ACCESS CONTROL FUZZ TESTS
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice FUZZ TEST: updateReputation access control vulnerability
     * @dev Tests that any address can manipulate verifier reputation
     */
    function testFuzz_UpdateReputation_AccessControl_Vulnerability(
        address attacker_addr,
        int256 reputationDelta,
        uint8 targetVerifierIndex
    ) public {
        // Bound inputs to reasonable ranges
        vm.assume(attacker_addr != address(0));
        vm.assume(attacker_addr != address(this));
        reputationDelta = bound(reputationDelta, -int256(MAX_REPUTATION), int256(MAX_REPUTATION));
        
        // Select target verifier
        address targetVerifier = targetVerifierIndex % 2 == 0 ? verifier1 : verifier2;
        
        // Record initial state
        uint256 initialReputation = dvnRegistry.getVerifierAgent(targetVerifier).reputation;
        uint256 initialWeight = dvnRegistry.getVerifierWeight(targetVerifier);
        
        emit LogFuzzInput("updateReputation_AccessControl", attacker_addr, 0, reputationDelta);
        
        // VULNERABILITY: Any address can call updateReputation
        vm.prank(attacker_addr);
        dvnRegistry.updateReputation(targetVerifier, reputationDelta);
        
        // Verify the reputation was actually changed
        uint256 finalReputation = dvnRegistry.getVerifierAgent(targetVerifier).reputation;
        uint256 finalWeight = dvnRegistry.getVerifierWeight(targetVerifier);
        
        // Calculate expected reputation
        uint256 expectedReputation;
        if (reputationDelta >= 0) {
            expectedReputation = initialReputation + uint256(reputationDelta);
            if (expectedReputation > MAX_REPUTATION) {
                expectedReputation = MAX_REPUTATION;
            }
        } else {
            uint256 decrease = uint256(-reputationDelta);
            expectedReputation = initialReputation > decrease ? initialReputation - decrease : 0;
        }
        
        // Verify vulnerability
        assertEq(finalReputation, expectedReputation, "Reputation manipulation failed");
        
        // Log if significant impact
        if (finalWeight != initialWeight) {
            emit LogVulnerabilityFound(
                "updateReputation_AccessControl",
                attacker_addr,
                finalWeight > initialWeight ? finalWeight - initialWeight : initialWeight - finalWeight
            );
        }
    }
    
    /**
     * @notice FUZZ TEST: slashStake access control vulnerability
     * @dev Tests that any address can slash verifier stakes
     */
    function testFuzz_SlashStake_AccessControl_Vulnerability(
        address attacker_addr,
        uint256 slashAmount,
        uint8 targetVerifierIndex
    ) public {
        // Bound inputs
        vm.assume(attacker_addr != address(0));
        vm.assume(attacker_addr != address(this));
        
        // Select target verifier
        address targetVerifier = targetVerifierIndex % 2 == 0 ? verifier1 : verifier2;
        
        // Get initial stake
        uint256 initialStake = dvnRegistry.getVerifierAgent(targetVerifier).stakedAmount;
        vm.assume(initialStake > 0);
        
        // Bound slash amount to not exceed initial stake
        slashAmount = bound(slashAmount, 1, initialStake);
        
        emit LogFuzzInput("slashStake_AccessControl", attacker_addr, slashAmount, 0);
        
        // VULNERABILITY: Any address can call slashStake
        vm.prank(attacker_addr);
        dvnRegistry.slashStake(targetVerifier, slashAmount);
        
        // Verify the stake was actually slashed
        uint256 finalStake = dvnRegistry.getVerifierAgent(targetVerifier).stakedAmount;
        uint256 expectedStake = initialStake - slashAmount;
        
        assertEq(finalStake, expectedStake, "Stake slashing failed");
        
        // Log significant slashing
        if (slashAmount > initialStake / 10) { // More than 10% slashed
            emit LogVulnerabilityFound(
                "slashStake_AccessControl",
                attacker_addr,
                slashAmount
            );
        }
    }
    
    /**
     * @notice FUZZ TEST: incrementSubmissionCount access control vulnerability
     * @dev Tests that any address can inflate worker submission statistics
     */
    function testFuzz_IncrementSubmissionCount_AccessControl_Vulnerability(
        address attacker_addr,
        uint256 inflationCount
    ) public {
        // Bound inputs
        vm.assume(attacker_addr != address(0));
        vm.assume(attacker_addr != address(this));
        inflationCount = bound(inflationCount, 1, 1000); // Reasonable upper bound
        
        // Record initial submission count
        uint256 initialCount = dvnRegistry.getWorkerAgent(worker1).submissionCount;
        
        emit LogFuzzInput("incrementSubmissionCount_AccessControl", attacker_addr, inflationCount, 0);
        
        // VULNERABILITY: Any address can call incrementSubmissionCount
        vm.prank(attacker_addr);
        for (uint256 i = 0; i < inflationCount; i++) {
            dvnRegistry.incrementSubmissionCount(worker1);
        }
        
        // Verify the count was actually inflated
        uint256 finalCount = dvnRegistry.getWorkerAgent(worker1).submissionCount;
        uint256 expectedCount = initialCount + inflationCount;
        
        assertEq(finalCount, expectedCount, "Submission count inflation failed");
        
        // Log significant inflation
        if (inflationCount > 50) {
            emit LogVulnerabilityFound(
                "incrementSubmissionCount_AccessControl",
                attacker_addr,
                inflationCount
            );
        }
    }
    
    /*//////////////////////////////////////////////////////////////
                        ECONOMIC ATTACK FUZZ TESTS
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice FUZZ TEST: Combined reputation and stake manipulation attack
     * @dev Tests combined attacks that can eliminate verifiers from consensus
     */
    function testFuzz_CombinedEconomicAttack(
        address attacker_addr,
        int256 reputationDelta,
        uint256 slashRatio, // Percentage of stake to slash (0-100)
        uint8 targetVerifierIndex
    ) public {
        // Bound inputs
        vm.assume(attacker_addr != address(0));
        vm.assume(attacker_addr != address(this));
        reputationDelta = bound(reputationDelta, -int256(MAX_REPUTATION), int256(MAX_REPUTATION));
        slashRatio = bound(slashRatio, 0, 100);
        
        // Select target verifier
        address targetVerifier = targetVerifierIndex % 2 == 0 ? verifier1 : verifier2;
        
        // Record initial state
        uint256 initialStake = dvnRegistry.getVerifierAgent(targetVerifier).stakedAmount;
        uint256 initialReputation = dvnRegistry.getVerifierAgent(targetVerifier).reputation;
        uint256 initialWeight = dvnRegistry.getVerifierWeight(targetVerifier);
        
        vm.assume(initialStake > 0);
        
        // Calculate slash amount
        uint256 slashAmount = (initialStake * slashRatio) / 100;
        slashAmount = slashAmount > initialStake ? initialStake : slashAmount;
        
        emit LogFuzzInput("combinedEconomicAttack", attacker_addr, slashAmount, reputationDelta);
        
        // Execute combined attack
        vm.startPrank(attacker_addr);
        
        // First: Manipulate reputation
        dvnRegistry.updateReputation(targetVerifier, reputationDelta);
        
        // Second: Slash stake
        if (slashAmount > 0) {
            dvnRegistry.slashStake(targetVerifier, slashAmount);
        }
        
        vm.stopPrank();
        
        // Verify final state
        uint256 finalStake = dvnRegistry.getVerifierAgent(targetVerifier).stakedAmount;
        uint256 finalReputation = dvnRegistry.getVerifierAgent(targetVerifier).reputation;
        uint256 finalWeight = dvnRegistry.getVerifierWeight(targetVerifier);
        
        // Calculate impact
        uint256 weightLoss = initialWeight > finalWeight ? initialWeight - finalWeight : 0;
        
        // Log critical attacks that eliminate verifiers
        if (finalWeight == 0 && initialWeight > 0) {
            emit LogVulnerabilityFound(
                "combinedEconomicAttack_CompleteElimination",
                attacker_addr,
                initialWeight
            );
        } else if (weightLoss > initialWeight / 2) {
            emit LogVulnerabilityFound(
                "combinedEconomicAttack_MajorDamage",
                attacker_addr,
                weightLoss
            );
        }
    }
    
    /**
     * @notice FUZZ TEST: Mass verifier manipulation attack
     * @dev Tests attacking multiple verifiers simultaneously
     */
    function testFuzz_MassVerifierManipulation(
        address attacker_addr,
        int256 reputationDelta1,
        int256 reputationDelta2,
        uint256 slashRatio1,
        uint256 slashRatio2
    ) public {
        // Bound inputs
        vm.assume(attacker_addr != address(0));
        vm.assume(attacker_addr != address(this));
        reputationDelta1 = bound(reputationDelta1, -int256(MAX_REPUTATION), int256(MAX_REPUTATION));
        reputationDelta2 = bound(reputationDelta2, -int256(MAX_REPUTATION), int256(MAX_REPUTATION));
        slashRatio1 = bound(slashRatio1, 0, 100);
        slashRatio2 = bound(slashRatio2, 0, 100);
        
        // Record initial states
        uint256 initialWeight1 = dvnRegistry.getVerifierWeight(verifier1);
        uint256 initialWeight2 = dvnRegistry.getVerifierWeight(verifier2);
        uint256 totalInitialWeight = initialWeight1 + initialWeight2;
        
        uint256 initialStake1 = dvnRegistry.getVerifierAgent(verifier1).stakedAmount;
        uint256 initialStake2 = dvnRegistry.getVerifierAgent(verifier2).stakedAmount;
        
        // Calculate slash amounts
        uint256 slashAmount1 = (initialStake1 * slashRatio1) / 100;
        uint256 slashAmount2 = (initialStake2 * slashRatio2) / 100;
        
        slashAmount1 = slashAmount1 > initialStake1 ? initialStake1 : slashAmount1;
        slashAmount2 = slashAmount2 > initialStake2 ? initialStake2 : slashAmount2;
        
        // Execute mass attack
        vm.startPrank(attacker_addr);
        
        // Attack verifier 1
        dvnRegistry.updateReputation(verifier1, reputationDelta1);
        if (slashAmount1 > 0) {
            dvnRegistry.slashStake(verifier1, slashAmount1);
        }
        
        // Attack verifier 2
        dvnRegistry.updateReputation(verifier2, reputationDelta2);
        if (slashAmount2 > 0) {
            dvnRegistry.slashStake(verifier2, slashAmount2);
        }
        
        vm.stopPrank();
        
        // Verify final states
        uint256 finalWeight1 = dvnRegistry.getVerifierWeight(verifier1);
        uint256 finalWeight2 = dvnRegistry.getVerifierWeight(verifier2);
        uint256 totalFinalWeight = finalWeight1 + finalWeight2;
        
        // Calculate total impact
        uint256 totalWeightLoss = totalInitialWeight > totalFinalWeight ? 
            totalInitialWeight - totalFinalWeight : 0;
        
        // Log critical attacks affecting consensus
        if (totalFinalWeight == 0 && totalInitialWeight > 0) {
            emit LogVulnerabilityFound(
                "massVerifierManipulation_CompleteConsensusFailure",
                attacker_addr,
                totalInitialWeight
            );
        } else if (totalWeightLoss > totalInitialWeight / 2) {
            emit LogVulnerabilityFound(
                "massVerifierManipulation_MajorConsensusWeakening",
                attacker_addr,
                totalWeightLoss
            );
        }
    }
    
    /*//////////////////////////////////////////////////////////////
                        EDGE CASE FUZZ TESTS
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice FUZZ TEST: Integer overflow/underflow in reputation updates
     * @dev Tests boundary conditions for reputation manipulation
     */
    function testFuzz_ReputationBoundaryConditions(
        address attacker_addr,
        int256 extremeReputationDelta
    ) public {
        vm.assume(attacker_addr != address(0));
        vm.assume(attacker_addr != address(this));
        
        // Test extreme values
        extremeReputationDelta = bound(extremeReputationDelta, 
            -int256(type(uint256).max/2), int256(type(uint256).max/2));
        
        // Record initial state
        uint256 initialReputation = dvnRegistry.getVerifierAgent(verifier1).reputation;
        
        // Test extreme reputation manipulation
        vm.prank(attacker_addr);
        dvnRegistry.updateReputation(verifier1, extremeReputationDelta);
        
        // Verify bounds are respected
        uint256 finalReputation = dvnRegistry.getVerifierAgent(verifier1).reputation;
        
        assertLe(finalReputation, MAX_REPUTATION, "Reputation exceeded maximum");
        assertGe(finalReputation, 0, "Reputation went below zero");
    }
    
    /**
     * @notice FUZZ TEST: Stake slashing boundary conditions
     * @dev Tests edge cases in stake slashing
     */
    function testFuzz_StakeSlashingBoundaryConditions(
        address attacker_addr,
        uint256 extremeSlashAmount
    ) public {
        vm.assume(attacker_addr != address(0));
        vm.assume(attacker_addr != address(this));
        
        // Get initial stake
        uint256 initialStake = dvnRegistry.getVerifierAgent(verifier1).stakedAmount;
        
        // Test with extreme slash amounts
        extremeSlashAmount = bound(extremeSlashAmount, 0, initialStake + 1 ether);
        
        if (extremeSlashAmount <= initialStake) {
            // Should succeed
            vm.prank(attacker_addr);
            dvnRegistry.slashStake(verifier1, extremeSlashAmount);
            
            uint256 finalStake = dvnRegistry.getVerifierAgent(verifier1).stakedAmount;
            assertEq(finalStake, initialStake - extremeSlashAmount, "Incorrect stake after slashing");
        } else {
            // Should revert
            vm.prank(attacker_addr);
            vm.expectRevert("Insufficient stake to slash");
            dvnRegistry.slashStake(verifier1, extremeSlashAmount);
        }
    }
    
    /*//////////////////////////////////////////////////////////////
                        INVARIANT TESTS
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice INVARIANT: Verifier reputation should stay within bounds
     */
    function invariant_ReputationBounds() public view {
        address[] memory verifiers = dvnRegistry.getAllVerifiers();
        
        for (uint256 i = 0; i < verifiers.length; i++) {
            uint256 reputation = dvnRegistry.getVerifierAgent(verifiers[i]).reputation;
            assert(reputation <= MAX_REPUTATION);
        }
    }
    
    /**
     * @notice INVARIANT: Total staked amount should never exceed sum of individual stakes
     */
    function invariant_TotalStakedAmount() public view {
        address[] memory verifiers = dvnRegistry.getAllVerifiers();
        uint256 sumOfStakes = 0;
        
        for (uint256 i = 0; i < verifiers.length; i++) {
            sumOfStakes += dvnRegistry.getVerifierAgent(verifiers[i]).stakedAmount;
        }
        
        assert(dvnRegistry.totalStakedAmount() == sumOfStakes);
    }
    
    /**
     * @notice INVARIANT: Verifier weight calculation should be correct
     */
    function invariant_VerifierWeightCalculation() public view {
        address[] memory verifiers = dvnRegistry.getAllVerifiers();
        
        for (uint256 i = 0; i < verifiers.length; i++) {
            address verifier = verifiers[i];
            DVNRegistryPOC.VerifierAgentInfo memory info = dvnRegistry.getVerifierAgent(verifier);
            uint256 weight = dvnRegistry.getVerifierWeight(verifier);
            
            if (info.isActive && info.stakedAmount >= MINIMUM_STAKE) {
                assert(weight == info.stakedAmount * info.reputation);
            } else {
                assert(weight == 0);
            }
        }
    }
} 