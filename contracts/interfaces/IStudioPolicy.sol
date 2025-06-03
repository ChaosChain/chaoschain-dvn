// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IStudioPolicy
 * @dev Standard interface that all Studio contracts must implement for DVN integration
 * @notice This interface defines the contract between Studios and the DVN system
 */
interface IStudioPolicy {
    
    enum PoAStatus { 
        SUBMITTED,    // Initial state when work is submitted
        VERIFIED,     // DVN consensus approved the submission
        REJECTED,     // DVN consensus rejected the submission
        DISPUTED      // No clear consensus reached
    }

    /**
     * @dev Struct representing a Proof-of-Agency submission
     */
    struct PoASubmission {
        bytes32 agentId;        // ID of the Worker Agent
        string actionType;      // Type of action performed (e.g., "KiranaAI_StockReport")
        string metadataURI;     // IPFS hash containing the submission package
        PoAStatus status;       // Current status of the submission
        address submitter;      // Address of the submitting agent
        uint256 timestamp;      // When the submission was created
    }

    /**
     * @notice Submit work for verification by the DVN
     * @param agentId The ID of the Worker Agent submitting work
     * @param actionType The type of action performed
     * @param metadataURI IPFS hash containing the submission package
     * @return poaId Unique identifier for this submission
     */
    function submitWork(
        bytes32 agentId, 
        string memory actionType, 
        string memory metadataURI
    ) external payable returns (bytes32 poaId);

    /**
     * @notice Update the status of a PoA submission (callable only by DVN Consensus contract)
     * @param poaId The unique identifier of the submission
     * @param newStatus The new status to set
     */
    function updatePoAStatus(bytes32 poaId, PoAStatus newStatus) external;

    /**
     * @notice Get details of a specific PoA submission
     * @param poaId The unique identifier of the submission
     * @return submission The PoA submission details
     */
    function getPoASubmission(bytes32 poaId) external view returns (PoASubmission memory submission);

    /**
     * @notice Check if a submission exists
     * @param poaId The unique identifier to check
     * @return exists True if the submission exists
     */
    function submissionExists(bytes32 poaId) external view returns (bool exists);

    // Events
    event WorkSubmitted(
        bytes32 indexed poaId,
        bytes32 indexed agentId,
        string actionType,
        string metadataURI,
        address indexed submitter
    );

    event PoAStatusUpdated(
        bytes32 indexed poaId,
        PoAStatus indexed oldStatus,
        PoAStatus indexed newStatus
    );
} 