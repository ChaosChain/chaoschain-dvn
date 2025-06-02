// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./interfaces/IStudioPolicy.sol";

/**
 * @title DVNConsensusPOC
 * @dev Processes attestations and finalizes Proof-of-Agency status
 * @notice This contract implements the simplified consensus algorithm for the PoC
 */
contract DVNConsensusPOC {

    // Consensus parameters
    uint256 public constant MINIMUM_ATTESTATIONS = 3;
    uint256 public constant CONSENSUS_THRESHOLD_PERCENT = 66; // 66% threshold
    uint256 public constant ATTESTATION_TIMEOUT = 10 minutes;

    // Contract references
    address public dvnRegistryContract;
    address public dvnAttestationContract;
    address public owner;

    // Registered studios
    mapping(address => bool) public registeredStudios;
    address[] public studioList;

    // Consensus tracking
    mapping(bytes32 => uint256) public submissionOpenTime;
    mapping(bytes32 => bool) public consensusProcessed;
    mapping(bytes32 => IStudioPolicy.PoAStatus) public finalStatuses;

    // Statistics
    uint256 public totalProcessedSubmissions;
    uint256 public totalVerifiedSubmissions;
    uint256 public totalRejectedSubmissions;
    uint256 public totalDisputedSubmissions;

    // Events
    event StudioRegistered(address indexed studio, string studioName);
    event StudioDeregistered(address indexed studio);
    
    event SubmissionProcessingStarted(
        bytes32 indexed poaId,
        address indexed studio,
        uint256 startTime
    );

    event ProofOfAgencyFinalized(
        bytes32 indexed poaId,
        IStudioPolicy.PoAStatus indexed status,
        uint256 totalAttestations,
        uint256 approvalCount,
        uint256 rejectionCount
    );

    event ConsensusTimeoutReached(
        bytes32 indexed poaId,
        uint256 timeoutTime,
        uint256 attestationCount
    );

    event RewardsDistributed(
        bytes32 indexed poaId,
        address[] verifiers,
        uint256 totalReward
    );

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyRegisteredStudio() {
        require(registeredStudios[msg.sender], "Only registered studios can call this");
        _;
    }

    modifier validPoAId(bytes32 poaId) {
        require(poaId != bytes32(0), "Invalid PoA ID");
        _;
    }

    modifier notAlreadyProcessed(bytes32 poaId) {
        require(!consensusProcessed[poaId], "Consensus already processed for this submission");
        _;
    }

    constructor(address _dvnRegistryContract, address _dvnAttestationContract) {
        owner = msg.sender;
        dvnRegistryContract = _dvnRegistryContract;
        dvnAttestationContract = _dvnAttestationContract;
    }

    /**
     * @notice Register a studio contract with the DVN
     * @param studio Address of the studio contract
     * @param studioName Name of the studio for identification
     */
    function registerStudio(address studio, string memory studioName) external onlyOwner {
        require(studio != address(0), "Invalid studio address");
        require(!registeredStudios[studio], "Studio already registered");

        registeredStudios[studio] = true;
        studioList.push(studio);

        emit StudioRegistered(studio, studioName);
    }

    /**
     * @notice Deregister a studio contract
     * @param studio Address of the studio contract to deregister
     */
    function deregisterStudio(address studio) external onlyOwner {
        require(registeredStudios[studio], "Studio not registered");
        
        registeredStudios[studio] = false;
        
        // Remove from studio list (expensive operation, consider optimization for production)
        for (uint256 i = 0; i < studioList.length; i++) {
            if (studioList[i] == studio) {
                studioList[i] = studioList[studioList.length - 1];
                studioList.pop();
                break;
            }
        }

        emit StudioDeregistered(studio);
    }

    /**
     * @notice Start processing a submission (called when a new submission is made)
     * @param poaId The PoA submission ID
     * @param studioAddress Address of the submitting studio
     */
    function startSubmissionProcessing(bytes32 poaId, address studioAddress) external onlyRegisteredStudio validPoAId(poaId) {
        require(submissionOpenTime[poaId] == 0, "Submission already being processed");
        
        submissionOpenTime[poaId] = block.timestamp;
        
        // Open submission for attestations in the attestation contract
        (bool success, ) = dvnAttestationContract.call(
            abi.encodeWithSignature("openSubmissionForAttestation(bytes32)", poaId)
        );
        require(success, "Failed to open submission for attestation");

        emit SubmissionProcessingStarted(poaId, studioAddress, block.timestamp);
    }

    /**
     * @notice Process consensus for a PoA submission
     * @param poaId The PoA submission ID
     * @param studioAddress Address of the studio contract
     */
    function processConsensus(bytes32 poaId, address studioAddress) external validPoAId(poaId) notAlreadyProcessed(poaId) {
        require(submissionOpenTime[poaId] != 0, "Submission not started");
        require(registeredStudios[studioAddress], "Invalid studio address");

        // Get attestation data
        (bool success, bytes memory data) = dvnAttestationContract.call(
            abi.encodeWithSignature("getApprovalCounts(bytes32)", poaId)
        );
        require(success, "Failed to get attestation counts");
        
        (uint256 approvalCount, uint256 rejectionCount) = abi.decode(data, (uint256, uint256));
        uint256 totalAttestations = approvalCount + rejectionCount;

        // Check if we have minimum attestations or if timeout reached
        bool hasMinimumAttestations = totalAttestations >= MINIMUM_ATTESTATIONS;
        bool timeoutReached = block.timestamp >= submissionOpenTime[poaId] + ATTESTATION_TIMEOUT;
        
        require(hasMinimumAttestations || timeoutReached, "Insufficient attestations and timeout not reached");

        if (timeoutReached && !hasMinimumAttestations) {
            emit ConsensusTimeoutReached(poaId, block.timestamp, totalAttestations);
        }

        // Calculate consensus
        IStudioPolicy.PoAStatus finalStatus = calculateConsensus(approvalCount, rejectionCount, totalAttestations);
        
        // Mark as processed
        consensusProcessed[poaId] = true;
        finalStatuses[poaId] = finalStatus;

        // Close submission for attestations
        (success, ) = dvnAttestationContract.call(
            abi.encodeWithSignature("closeSubmissionForAttestation(bytes32)", poaId)
        );
        require(success, "Failed to close submission for attestation");

        // Update studio contract
        (success, ) = studioAddress.call(
            abi.encodeWithSignature("updatePoAStatus(bytes32,uint8)", poaId, uint8(finalStatus))
        );
        require(success, "Failed to update studio PoA status");

        // Update statistics
        totalProcessedSubmissions++;
        if (finalStatus == IStudioPolicy.PoAStatus.VERIFIED) {
            totalVerifiedSubmissions++;
        } else if (finalStatus == IStudioPolicy.PoAStatus.REJECTED) {
            totalRejectedSubmissions++;
        } else if (finalStatus == IStudioPolicy.PoAStatus.DISPUTED) {
            totalDisputedSubmissions++;
        }

        emit ProofOfAgencyFinalized(poaId, finalStatus, totalAttestations, approvalCount, rejectionCount);

        // Distribute rewards to participating verifiers
        distributeRewards(poaId);
    }

    /**
     * @notice Calculate consensus based on attestations (simplified algorithm)
     * @param approvalCount Number of approval attestations
     * @param rejectionCount Number of rejection attestations
     * @param totalAttestations Total number of attestations
     * @return status The calculated PoA status
     */
    function calculateConsensus(
        uint256 approvalCount,
        uint256 rejectionCount,
        uint256 totalAttestations
    ) internal pure returns (IStudioPolicy.PoAStatus status) {
        if (totalAttestations == 0) {
            return IStudioPolicy.PoAStatus.DISPUTED;
        }

        // Calculate percentages
        uint256 approvalPercent = (approvalCount * 100) / totalAttestations;
        uint256 rejectionPercent = (rejectionCount * 100) / totalAttestations;

        // Apply consensus threshold
        if (approvalPercent >= CONSENSUS_THRESHOLD_PERCENT) {
            return IStudioPolicy.PoAStatus.VERIFIED;
        } else if (rejectionPercent >= CONSENSUS_THRESHOLD_PERCENT) {
            return IStudioPolicy.PoAStatus.REJECTED;
        } else {
            return IStudioPolicy.PoAStatus.DISPUTED;
        }
    }

    /**
     * @notice Distribute rewards to verifiers (simplified for PoC)
     * @param poaId The PoA submission ID
     */
    function distributeRewards(bytes32 poaId) internal {
        // Get list of attestors
        (bool success, bytes memory data) = dvnAttestationContract.call(
            abi.encodeWithSignature("getAttestorsByPoA(bytes32)", poaId)
        );
        
        if (success) {
            address[] memory attestors = abi.decode(data, (address[]));
            
            // For PoC, we'll just emit an event
            // In production, this would handle actual token rewards
            if (attestors.length > 0) {
                emit RewardsDistributed(poaId, attestors, 0);
            }
        }
    }

    /**
     * @notice Get the final status of a PoA submission
     * @param poaId The PoA submission ID
     * @return status The final PoA status
     */
    function getPoAStatus(bytes32 poaId) external view validPoAId(poaId) returns (IStudioPolicy.PoAStatus status) {
        if (!consensusProcessed[poaId]) {
            return IStudioPolicy.PoAStatus.SUBMITTED;
        }
        return finalStatuses[poaId];
    }

    /**
     * @notice Check if consensus has been processed for a submission
     * @param poaId The PoA submission ID
     * @return processed Whether consensus has been processed
     */
    function isConsensusProcessed(bytes32 poaId) external view validPoAId(poaId) returns (bool processed) {
        return consensusProcessed[poaId];
    }

    /**
     * @notice Get time remaining before timeout
     * @param poaId The PoA submission ID
     * @return timeRemaining Seconds remaining before timeout (0 if timed out)
     */
    function getTimeRemaining(bytes32 poaId) external view validPoAId(poaId) returns (uint256 timeRemaining) {
        uint256 openTime = submissionOpenTime[poaId];
        if (openTime == 0) {
            return 0; // Not started
        }
        
        uint256 timeoutTime = openTime + ATTESTATION_TIMEOUT;
        if (block.timestamp >= timeoutTime) {
            return 0; // Timed out
        }
        
        return timeoutTime - block.timestamp;
    }

    /**
     * @notice Get consensus requirements
     * @return minAttestations Minimum number of attestations required
     * @return thresholdPercent Consensus threshold percentage
     * @return timeoutDuration Timeout duration in seconds
     */
    function getConsensusRequirements() external pure returns (
        uint256 minAttestations,
        uint256 thresholdPercent,
        uint256 timeoutDuration
    ) {
        return (MINIMUM_ATTESTATIONS, CONSENSUS_THRESHOLD_PERCENT, ATTESTATION_TIMEOUT);
    }

    /**
     * @notice Get all registered studios
     * @return studios Array of registered studio addresses
     */
    function getRegisteredStudios() external view returns (address[] memory studios) {
        return studioList;
    }

    /**
     * @notice Get consensus statistics
     * @return totalProcessed Total number of processed submissions
     * @return totalVerified Total number of verified submissions
     * @return totalRejected Total number of rejected submissions
     * @return totalDisputed Total number of disputed submissions
     */
    function getConsensusStats() external view returns (
        uint256 totalProcessed,
        uint256 totalVerified,
        uint256 totalRejected,
        uint256 totalDisputed
    ) {
        return (
            totalProcessedSubmissions,
            totalVerifiedSubmissions,
            totalRejectedSubmissions,
            totalDisputedSubmissions
        );
    }

    /**
     * @notice Emergency function to process stuck submissions (owner only)
     * @param poaId The PoA submission ID that's stuck
     * @param studioAddress Address of the studio contract
     */
    function emergencyProcessConsensus(bytes32 poaId, address studioAddress) external onlyOwner validPoAId(poaId) {
        require(submissionOpenTime[poaId] != 0, "Submission not started");
        require(block.timestamp >= submissionOpenTime[poaId] + (ATTESTATION_TIMEOUT * 2), "Not enough time passed");
        
        // Force process with whatever attestations we have
        this.processConsensus(poaId, studioAddress);
    }

    /**
     * @notice Update contract references (owner only)
     * @param _dvnRegistryContract New DVN registry contract address
     * @param _dvnAttestationContract New DVN attestation contract address
     */
    function updateContractReferences(
        address _dvnRegistryContract,
        address _dvnAttestationContract
    ) external onlyOwner {
        require(_dvnRegistryContract != address(0), "Invalid registry address");
        require(_dvnAttestationContract != address(0), "Invalid attestation address");
        
        dvnRegistryContract = _dvnRegistryContract;
        dvnAttestationContract = _dvnAttestationContract;
    }

    /**
     * @notice Transfer ownership (owner only)
     * @param newOwner The new owner address
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        owner = newOwner;
    }
} 