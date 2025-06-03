// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./interfaces/IStudioPolicy.sol";

/**
 * @title StudioPOC
 * @dev Example Studio contract for the KiranaAI inventory verification scenario
 * @notice This contract demonstrates how Studios integrate with the DVN system
 */
contract StudioPOC is IStudioPolicy {
    
    // Studio-specific constants
    string public constant STUDIO_NAME = "KiranaAI-POC-Studio";
    string public constant STUDIO_VERSION = "1.0.0";
    uint256 public constant VERIFICATION_FEE = 0.0001 ether;
    
    // Submission management
    mapping(bytes32 => PoASubmission) public poaSubmissions;
    bytes32[] public allSubmissions;
    
    // Access control
    address public owner;
    address public dvnConsensusContract;
    address public dvnRegistryContract;
    
    // Studio statistics
    uint256 public totalSubmissions;
    uint256 public verifiedSubmissions;
    uint256 public rejectedSubmissions;
    
    // Additional events specific to this studio
    event StudioConfigUpdated(
        address indexed dvnConsensusContract,
        address indexed dvnRegistryContract
    );

    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyDVNConsensus() {
        require(msg.sender == dvnConsensusContract, "Only DVN consensus contract can call this");
        _;
    }

    modifier onlyRegisteredWorker() {
        // For PoC, we'll do a simple check or make it open
        // In production, this would check against DVN Registry
        require(msg.sender != address(0), "Invalid worker address");
        _;
    }

    modifier validActionType(string memory actionType) {
        // For KiranaAI Studio, we accept specific action types
        bytes32 actionHash = keccak256(abi.encodePacked(actionType));
        require(
            actionHash == keccak256(abi.encodePacked("KiranaAI_StockReport")) ||
            actionHash == keccak256(abi.encodePacked("KiranaAI_InventoryAudit")) ||
            actionHash == keccak256(abi.encodePacked("KiranaAI_ReorderAlert")),
            "Invalid action type for this studio"
        );
        _;
    }

    constructor(address _dvnRegistryContract) {
        owner = msg.sender;
        dvnRegistryContract = _dvnRegistryContract;
    }

    /**
     * @notice Set the DVN consensus contract address
     * @param _dvnConsensusContract Address of the DVN consensus contract
     */
    function setDVNConsensusContract(address _dvnConsensusContract) external onlyOwner {
        dvnConsensusContract = _dvnConsensusContract;
        emit StudioConfigUpdated(_dvnConsensusContract, dvnRegistryContract);
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
    ) external payable onlyRegisteredWorker validActionType(actionType) returns (bytes32 poaId) {
        require(msg.value >= VERIFICATION_FEE, "Insufficient verification fee");
        require(agentId != bytes32(0), "Invalid agent ID");
        require(bytes(metadataURI).length > 0, "Metadata URI cannot be empty");

        // Generate unique PoA ID
        poaId = keccak256(abi.encodePacked(
            agentId,
            actionType,
            metadataURI,
            block.timestamp,
            msg.sender,
            totalSubmissions
        ));

        require(!submissionExists(poaId), "Submission already exists");

        // Create and store submission
        poaSubmissions[poaId] = PoASubmission({
            agentId: agentId,
            actionType: actionType,
            metadataURI: metadataURI,
            status: PoAStatus.SUBMITTED,
            submitter: msg.sender,
            timestamp: block.timestamp
        });

        allSubmissions.push(poaId);
        totalSubmissions++;

        emit WorkSubmitted(poaId, agentId, actionType, metadataURI, msg.sender);

        return poaId;
    }

    /**
     * @notice Update the status of a PoA submission (callable only by DVN Consensus contract)
     * @param poaId The unique identifier of the submission
     * @param newStatus The new status to set
     */
    function updatePoAStatus(bytes32 poaId, PoAStatus newStatus) external onlyDVNConsensus {
        require(submissionExists(poaId), "Submission does not exist");
        
        PoASubmission storage submission = poaSubmissions[poaId];
        PoAStatus oldStatus = submission.status;
        
        require(oldStatus != newStatus, "Status unchanged");
        require(oldStatus == PoAStatus.SUBMITTED, "Can only update submitted submissions");

        submission.status = newStatus;

        // Update statistics
        if (newStatus == PoAStatus.VERIFIED) {
            verifiedSubmissions++;
        } else if (newStatus == PoAStatus.REJECTED) {
            rejectedSubmissions++;
        }

        emit PoAStatusUpdated(poaId, oldStatus, newStatus);
    }

    /**
     * @notice Get details of a specific PoA submission
     * @param poaId The unique identifier of the submission
     * @return submission The PoA submission details
     */
    function getPoASubmission(bytes32 poaId) external view returns (PoASubmission memory submission) {
        require(submissionExists(poaId), "Submission does not exist");
        return poaSubmissions[poaId];
    }

    /**
     * @notice Check if a submission exists
     * @param poaId The unique identifier to check
     * @return exists True if the submission exists
     */
    function submissionExists(bytes32 poaId) public view returns (bool exists) {
        return poaSubmissions[poaId].timestamp != 0;
    }

    /**
     * @notice Get all submission IDs
     * @return submissionIds Array of all submission IDs
     */
    function getAllSubmissions() external view returns (bytes32[] memory submissionIds) {
        return allSubmissions;
    }

    /**
     * @notice Get submissions by status
     * @param status The status to filter by
     * @return filteredSubmissions Array of submission IDs with the specified status
     */
    function getSubmissionsByStatus(PoAStatus status) external view returns (bytes32[] memory filteredSubmissions) {
        uint256 count = 0;
        
        // First pass: count matching submissions
        for (uint256 i = 0; i < allSubmissions.length; i++) {
            if (poaSubmissions[allSubmissions[i]].status == status) {
                count++;
            }
        }

        // Second pass: populate array
        filteredSubmissions = new bytes32[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < allSubmissions.length; i++) {
            if (poaSubmissions[allSubmissions[i]].status == status) {
                filteredSubmissions[index] = allSubmissions[i];
                index++;
            }
        }

        return filteredSubmissions;
    }

    /**
     * @notice Get submissions by agent
     * @param agentId The agent ID to filter by
     * @return agentSubmissions Array of submission IDs from the specified agent
     */
    function getSubmissionsByAgent(bytes32 agentId) external view returns (bytes32[] memory agentSubmissions) {
        uint256 count = 0;
        
        // First pass: count matching submissions
        for (uint256 i = 0; i < allSubmissions.length; i++) {
            if (poaSubmissions[allSubmissions[i]].agentId == agentId) {
                count++;
            }
        }

        // Second pass: populate array
        agentSubmissions = new bytes32[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < allSubmissions.length; i++) {
            if (poaSubmissions[allSubmissions[i]].agentId == agentId) {
                agentSubmissions[index] = allSubmissions[i];
                index++;
            }
        }

        return agentSubmissions;
    }

    /**
     * @notice Get studio statistics
     * @return total Total number of submissions
     * @return verified Total number of verified submissions
     * @return rejected Total number of rejected submissions
     * @return pending Total number of pending submissions
     */
    function getStudioStats() external view returns (
        uint256 total,
        uint256 verified,
        uint256 rejected,
        uint256 pending
    ) {
        return (
            totalSubmissions,
            verifiedSubmissions,
            rejectedSubmissions,
            totalSubmissions - verifiedSubmissions - rejectedSubmissions
        );
    }

    /**
     * @notice Withdraw accumulated fees (owner only)
     */
    function withdrawFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");

        (bool success, ) = owner.call{value: balance}("");
        require(success, "Transfer failed");
    }

    /**
     * @notice Get contract balance
     * @return balance The current contract balance
     */
    function getBalance() external view returns (uint256 balance) {
        return address(this).balance;
    }

    /**
     * @notice Emergency function to update owner
     * @param newOwner The new owner address
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        owner = newOwner;
    }
} 