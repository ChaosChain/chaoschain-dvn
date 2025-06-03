// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title DVNRegistryPOC
 * @dev Manages Verifier Agent registration, staking, and reputation for the DVN PoC
 * @notice This is a simplified version for proof-of-concept demonstration
 */
contract DVNRegistryPOC {
    
    enum AgentType { 
        WORKER,     // Worker Agent that submits work
        VERIFIER    // Verifier Agent that validates submissions
    }

    struct VerifierAgentInfo {
        bytes32 agentId;
        address agentAddress;
        uint256 stakedAmount;
        uint256 reputation;     // Simple reputation score (starts at 100)
        bool isActive;
        uint256 registrationTime;
        string endpoint;        // Optional endpoint for off-chain communication
    }

    struct WorkerAgentInfo {
        bytes32 agentId;
        address agentAddress;
        bool isActive;
        uint256 registrationTime;
        uint256 submissionCount;
    }

    // Constants
    uint256 public constant MINIMUM_STAKE = 0.001 ether;  // Minimum stake for VAs
    uint256 public constant INITIAL_REPUTATION = 100;     // Starting reputation score
    uint256 public constant MAX_REPUTATION = 1000;        // Maximum reputation score

    // State variables
    mapping(address => VerifierAgentInfo) public verifierAgents;
    mapping(address => WorkerAgentInfo) public workerAgents;
    mapping(bytes32 => address) public agentIdToAddress;
    
    address[] public registeredVerifiers;
    address[] public registeredWorkers;
    
    uint256 public totalRegisteredVAs;
    uint256 public totalRegisteredWAs;
    uint256 public totalStakedAmount;

    // Events
    event AgentRegistered(
        address indexed agentAddress,
        bytes32 indexed agentId,
        AgentType indexed agentType
    );
    
    event VAStaked(
        address indexed verifierAddress,
        uint256 amount,
        uint256 totalStake
    );
    
    event VAUnstaked(
        address indexed verifierAddress,
        uint256 amount,
        uint256 remainingStake
    );
    
    event ReputationUpdated(
        address indexed verifierAddress,
        uint256 oldReputation,
        uint256 newReputation
    );

    event AgentDeactivated(
        address indexed agentAddress,
        bytes32 indexed agentId,
        AgentType indexed agentType
    );

    // Modifiers
    modifier onlyRegisteredVerifier() {
        require(verifierAgents[msg.sender].isActive, "Not a registered verifier");
        _;
    }

    modifier onlyRegisteredWorker() {
        require(workerAgents[msg.sender].isActive, "Not a registered worker");
        _;
    }

    modifier validAgentId(bytes32 agentId) {
        require(agentId != bytes32(0), "Invalid agent ID");
        require(agentIdToAddress[agentId] == address(0), "Agent ID already exists");
        _;
    }

    /**
     * @notice Register a new agent (Worker or Verifier)
     * @param agentId Unique identifier for the agent
     * @param agentType Type of agent (WORKER or VERIFIER)
     * @param endpoint Optional endpoint for communication (empty string if not needed)
     */
    function registerAgent(
        bytes32 agentId,
        AgentType agentType,
        string memory endpoint
    ) external validAgentId(agentId) {
        require(!isRegisteredAgent(msg.sender), "Address already registered");

        agentIdToAddress[agentId] = msg.sender;

        if (agentType == AgentType.VERIFIER) {
            verifierAgents[msg.sender] = VerifierAgentInfo({
                agentId: agentId,
                agentAddress: msg.sender,
                stakedAmount: 0,
                reputation: INITIAL_REPUTATION,
                isActive: true,
                registrationTime: block.timestamp,
                endpoint: endpoint
            });
            registeredVerifiers.push(msg.sender);
            totalRegisteredVAs++;
        } else {
            workerAgents[msg.sender] = WorkerAgentInfo({
                agentId: agentId,
                agentAddress: msg.sender,
                isActive: true,
                registrationTime: block.timestamp,
                submissionCount: 0
            });
            registeredWorkers.push(msg.sender);
            totalRegisteredWAs++;
        }

        emit AgentRegistered(msg.sender, agentId, agentType);
    }

    /**
     * @notice Stake ETH for a Verifier Agent (mock staking for PoC)
     * @dev In production, this would handle actual token staking with slashing mechanisms
     */
    function mockStake() external payable onlyRegisteredVerifier {
        require(msg.value >= MINIMUM_STAKE, "Insufficient stake amount");

        verifierAgents[msg.sender].stakedAmount += msg.value;
        totalStakedAmount += msg.value;

        emit VAStaked(msg.sender, msg.value, verifierAgents[msg.sender].stakedAmount);
    }

    /**
     * @notice Unstake ETH for a Verifier Agent
     * @param amount Amount to unstake
     */
    function unstake(uint256 amount) external onlyRegisteredVerifier {
        VerifierAgentInfo storage va = verifierAgents[msg.sender];
        require(va.stakedAmount >= amount, "Insufficient staked amount");
        require(va.stakedAmount - amount >= MINIMUM_STAKE, "Cannot go below minimum stake");

        va.stakedAmount -= amount;
        totalStakedAmount -= amount;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        emit VAUnstaked(msg.sender, amount, va.stakedAmount);
    }

    /**
     * @notice Update reputation of a Verifier Agent (callable by consensus contract)
     * @param va Address of the Verifier Agent
     * @param reputationDelta Change in reputation (can be positive or negative)
     */
    function updateReputation(address va, int256 reputationDelta) external {
        // TODO: Add access control - only consensus contract should call this
        require(verifierAgents[va].isActive, "VA not active");

        uint256 oldReputation = verifierAgents[va].reputation;
        
        if (reputationDelta >= 0) {
            uint256 newRep = oldReputation + uint256(reputationDelta);
            verifierAgents[va].reputation = newRep > MAX_REPUTATION ? MAX_REPUTATION : newRep;
        } else {
            uint256 decrease = uint256(-reputationDelta);
            verifierAgents[va].reputation = oldReputation > decrease ? oldReputation - decrease : 0;
        }

        emit ReputationUpdated(va, oldReputation, verifierAgents[va].reputation);
    }

    /**
     * @notice Slash stake of a misbehaving Verifier Agent
     * @param va Address of the Verifier Agent
     * @param amount Amount to slash
     */
    function slashStake(address va, uint256 amount) external {
        // TODO: Add access control - only consensus contract should call this
        require(verifierAgents[va].isActive, "VA not active");
        require(verifierAgents[va].stakedAmount >= amount, "Insufficient stake to slash");

        verifierAgents[va].stakedAmount -= amount;
        totalStakedAmount -= amount;
        
        // Slashed funds remain in contract (could be redistributed or burned)
        // For PoC, we'll just keep them in the contract
    }

    /**
     * @notice Increment submission count for a Worker Agent
     * @param wa Address of the Worker Agent
     */
    function incrementSubmissionCount(address wa) external {
        // TODO: Add access control - only studio contracts should call this
        require(workerAgents[wa].isActive, "WA not active");
        workerAgents[wa].submissionCount++;
    }

    // View functions
    function getVerifierAgent(address va) external view returns (VerifierAgentInfo memory) {
        return verifierAgents[va];
    }

    function getWorkerAgent(address wa) external view returns (WorkerAgentInfo memory) {
        return workerAgents[wa];
    }

    function isRegisteredAgent(address agent) public view returns (bool) {
        return verifierAgents[agent].isActive || workerAgents[agent].isActive;
    }

    function isRegisteredVerifier(address agent) public view returns (bool) {
        return verifierAgents[agent].isActive;
    }

    function isRegisteredWorker(address agent) public view returns (bool) {
        return workerAgents[agent].isActive;
    }

    function getStakedVerifiers() external view returns (address[] memory) {
        uint256 count = 0;
        // First pass: count staked verifiers
        for (uint256 i = 0; i < registeredVerifiers.length; i++) {
            if (verifierAgents[registeredVerifiers[i]].stakedAmount >= MINIMUM_STAKE) {
                count++;
            }
        }

        // Second pass: populate array
        address[] memory stakedVerifiers = new address[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < registeredVerifiers.length; i++) {
            if (verifierAgents[registeredVerifiers[i]].stakedAmount >= MINIMUM_STAKE) {
                stakedVerifiers[index] = registeredVerifiers[i];
                index++;
            }
        }

        return stakedVerifiers;
    }

    function getAllVerifiers() external view returns (address[] memory) {
        return registeredVerifiers;
    }

    function getAllWorkers() external view returns (address[] memory) {
        return registeredWorkers;
    }

    /**
     * @notice Get total weight of a verifier (stake * reputation)
     * @param va Address of the verifier agent
     * @return weight The calculated weight
     */
    function getVerifierWeight(address va) external view returns (uint256 weight) {
        VerifierAgentInfo memory verifier = verifierAgents[va];
        if (!verifier.isActive || verifier.stakedAmount < MINIMUM_STAKE) {
            return 0;
        }
        return verifier.stakedAmount * verifier.reputation;
    }
} 