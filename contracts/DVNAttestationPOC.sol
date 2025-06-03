// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title DVNAttestationPOC
 * @dev Manages Verifier Agent attestations for PoA submissions
 * @notice This contract records and validates attestations from VAs
 */
contract DVNAttestationPOC {
    
    struct Attestation {
        address verifier;           // Address of the Verifier Agent
        bool isApproved;           // VA's judgment on the submission
        string justificationURI;   // Optional IPFS hash with detailed justification
        uint256 timestamp;         // When the attestation was submitted
        bytes signature;           // Cryptographic signature (for future use)
    }

    // Storage mappings
    mapping(bytes32 => mapping(address => Attestation)) public attestations;
    mapping(bytes32 => address[]) public attestorsByPoA;
    mapping(bytes32 => bool) public hasSubmissionPendingAttestations;
    
    // Access control
    address public dvnRegistryContract;
    address public dvnConsensusContract;
    address public owner;
    
    // Statistics
    uint256 public totalAttestations;
    mapping(address => uint256) public verifierAttestationCount;
    
    // Events
    event AttestationSubmitted(
        bytes32 indexed poaId,
        address indexed verifier,
        bool isApproved,
        string justificationURI
    );
    
    event AttestationUpdated(
        bytes32 indexed poaId,
        address indexed verifier,
        bool wasApproved,
        bool nowApproved
    );

    event SubmissionOpenedForAttestation(
        bytes32 indexed poaId,
        uint256 timestamp
    );

    event SubmissionClosedForAttestation(
        bytes32 indexed poaId,
        uint256 totalAttestors
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

    modifier onlyRegisteredVerifier() {
        // For PoC, we'll implement a basic check
        // In production, this would query the DVN Registry
        require(msg.sender != address(0), "Invalid verifier address");
        // TODO: Add actual registry check when integrated
        _;
    }

    modifier validPoAId(bytes32 poaId) {
        require(poaId != bytes32(0), "Invalid PoA ID");
        _;
    }

    modifier noDoubleVoting(bytes32 poaId) {
        require(
            attestations[poaId][msg.sender].verifier == address(0),
            "Verifier already attested to this submission"
        );
        _;
    }

    modifier submissionOpen(bytes32 poaId) {
        require(
            hasSubmissionPendingAttestations[poaId],
            "Submission not open for attestations"
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
    }

    /**
     * @notice Open a submission for attestations (called by consensus contract)
     * @param poaId The PoA submission ID to open for attestations
     */
    function openSubmissionForAttestation(bytes32 poaId) external onlyDVNConsensus validPoAId(poaId) {
        require(!hasSubmissionPendingAttestations[poaId], "Submission already open");
        
        hasSubmissionPendingAttestations[poaId] = true;
        emit SubmissionOpenedForAttestation(poaId, block.timestamp);
    }

    /**
     * @notice Submit an attestation for a PoA submission
     * @param poaId The PoA submission ID
     * @param isApproved Whether the VA approves the submission
     * @param justificationURI Optional IPFS hash with detailed justification
     */
    function submitAttestation(
        bytes32 poaId,
        bool isApproved,
        string memory justificationURI
    ) external 
        onlyRegisteredVerifier 
        validPoAId(poaId) 
        noDoubleVoting(poaId)
        submissionOpen(poaId)
    {
        // Create and store attestation
        attestations[poaId][msg.sender] = Attestation({
            verifier: msg.sender,
            isApproved: isApproved,
            justificationURI: justificationURI,
            timestamp: block.timestamp,
            signature: "" // For future use with cryptographic signatures
        });

        // Add to attestors list
        attestorsByPoA[poaId].push(msg.sender);
        
        // Update statistics
        totalAttestations++;
        verifierAttestationCount[msg.sender]++;

        emit AttestationSubmitted(poaId, msg.sender, isApproved, justificationURI);
    }

    /**
     * @notice Update an existing attestation (before consensus is reached)
     * @param poaId The PoA submission ID
     * @param newApproval New approval status
     * @param newJustificationURI New justification URI
     */
    function updateAttestation(
        bytes32 poaId,
        bool newApproval,
        string memory newJustificationURI
    ) external 
        onlyRegisteredVerifier 
        validPoAId(poaId)
        submissionOpen(poaId)
    {
        require(attestations[poaId][msg.sender].verifier != address(0), "No existing attestation");
        
        Attestation storage attestation = attestations[poaId][msg.sender];
        bool wasApproved = attestation.isApproved;
        
        attestation.isApproved = newApproval;
        attestation.justificationURI = newJustificationURI;
        attestation.timestamp = block.timestamp;

        emit AttestationUpdated(poaId, msg.sender, wasApproved, newApproval);
    }

    /**
     * @notice Close a submission for attestations (called by consensus contract)
     * @param poaId The PoA submission ID to close
     */
    function closeSubmissionForAttestation(bytes32 poaId) external onlyDVNConsensus validPoAId(poaId) {
        require(hasSubmissionPendingAttestations[poaId], "Submission not open");
        
        hasSubmissionPendingAttestations[poaId] = false;
        emit SubmissionClosedForAttestation(poaId, attestorsByPoA[poaId].length);
    }

    /**
     * @notice Get all attestations for a specific PoA submission
     * @param poaId The PoA submission ID
     * @return attestationList Array of attestations
     */
    function getAttestations(bytes32 poaId) external view validPoAId(poaId) returns (Attestation[] memory attestationList) {
        address[] memory attestors = attestorsByPoA[poaId];
        attestationList = new Attestation[](attestors.length);
        
        for (uint256 i = 0; i < attestors.length; i++) {
            attestationList[i] = attestations[poaId][attestors[i]];
        }
        
        return attestationList;
    }

    /**
     * @notice Get attestation from a specific verifier for a PoA submission
     * @param poaId The PoA submission ID
     * @param verifier The verifier address
     * @return attestation The attestation details
     */
    function getAttestationByVerifier(bytes32 poaId, address verifier) external view validPoAId(poaId) returns (Attestation memory attestation) {
        return attestations[poaId][verifier];
    }

    /**
     * @notice Get all attestors for a PoA submission
     * @param poaId The PoA submission ID
     * @return attestors Array of attestor addresses
     */
    function getAttestorsByPoA(bytes32 poaId) external view validPoAId(poaId) returns (address[] memory attestors) {
        return attestorsByPoA[poaId];
    }

    /**
     * @notice Get attestation count for a PoA submission
     * @param poaId The PoA submission ID
     * @return count Number of attestations
     */
    function getAttestationCount(bytes32 poaId) external view validPoAId(poaId) returns (uint256 count) {
        return attestorsByPoA[poaId].length;
    }

    /**
     * @notice Get approval count for a PoA submission
     * @param poaId The PoA submission ID
     * @return approvals Number of approval attestations
     * @return rejections Number of rejection attestations
     */
    function getApprovalCounts(bytes32 poaId) external view validPoAId(poaId) returns (uint256 approvals, uint256 rejections) {
        address[] memory attestors = attestorsByPoA[poaId];
        
        for (uint256 i = 0; i < attestors.length; i++) {
            if (attestations[poaId][attestors[i]].isApproved) {
                approvals++;
            } else {
                rejections++;
            }
        }
        
        return (approvals, rejections);
    }

    /**
     * @notice Check if a verifier has attested to a submission
     * @param poaId The PoA submission ID
     * @param verifier The verifier address
     * @return hasAttested Whether the verifier has attested
     */
    function hasVerifierAttested(bytes32 poaId, address verifier) external view validPoAId(poaId) returns (bool hasAttested) {
        return attestations[poaId][verifier].verifier != address(0);
    }

    /**
     * @notice Verify attestation signature (placeholder for future implementation)
     * @param poaId The PoA submission ID
     * @param va The verifier address
     * @param signature The signature to verify
     * @return isValid Whether the signature is valid
     */
    function verifyAttestationSignature(
        bytes32 poaId,
        address va,
        bytes calldata signature
    ) external pure returns (bool isValid) {
        // Placeholder implementation for PoC
        // In production, this would verify cryptographic signatures
        return signature.length > 0 && poaId != bytes32(0) && va != address(0);
    }

    /**
     * @notice Get verifier statistics
     * @param verifier The verifier address
     * @return totalAttestationsCount Number of attestations by this verifier
     * @return registrationTime Registration timestamp (placeholder)
     */
    function getVerifierStats(address verifier) external view returns (
        uint256 totalAttestationsCount,
        uint256 registrationTime
    ) {
        return (
            verifierAttestationCount[verifier],
            0 // TODO: Get from registry contract
        );
    }

    /**
     * @notice Get contract statistics
     * @return totalAttestationsCount Total number of attestations
     * @return openSubmissions Number of open submissions
     */
    function getContractStats() external view returns (
        uint256 totalAttestationsCount,
        uint256 openSubmissions
    ) {
        // Count open submissions (expensive operation, consider caching in production)
        uint256 openCount = 0;
        // Note: This is a simplified implementation
        // In production, we'd maintain a more efficient data structure
        
        return (totalAttestations, openCount);
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