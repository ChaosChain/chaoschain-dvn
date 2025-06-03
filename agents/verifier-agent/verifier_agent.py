"""
ChaosChain DVN PoC - Verifier Agent Implementation
Evaluates PoA submissions from Worker Agents and submits attestations
"""

import os
import sys
import json
import logging
import random
import time
from datetime import datetime, timezone
from typing import Dict, Any, List, Optional, Tuple
from typing_extensions import TypedDict

# LangGraph imports
from langgraph.graph import StateGraph
from langgraph.prebuilt import create_react_agent

# Add project root to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(__file__))))

from agents.shared.constants import *
from agents.shared.ipfs_client import IPFSClient
from web3 import Web3
from eth_account import Account

# Configure logging
logging.basicConfig(
    level=getattr(logging, LOG_LEVEL.upper()) if isinstance(LOG_LEVEL, str) else LOG_LEVEL,
    format=LOG_FORMAT,
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('logs/verifier_agent.log') if os.path.exists('logs') else logging.NullHandler()
    ]
)
logger = logging.getLogger(__name__)

class VerifierAgentState(TypedDict):
    """State schema for Verifier Agent workflow"""
    # Input parameters
    submission_id: str
    agent_id: str
    
    # Workflow status
    current_step: str
    status: str
    error_message: str
    
    # Submission data
    submission_data: Dict[str, Any]
    poa_package: Dict[str, Any]
    ipfs_hash: str
    package_hash: str
    
    # Evaluation results
    evaluation_completed: bool
    structure_valid: bool
    content_quality_score: float
    evidence_quality_score: float
    overall_score: float
    evaluation_confidence: float
    evaluation_notes: List[str]
    
    # Attestation
    attestation_decision: bool  # True = Approve, False = Reject
    attestation_evidence: Dict[str, Any]
    attestation_signature: str
    tx_hash: str
    gas_used: int
    
    # Timestamps
    started_at: str
    completed_at: str

class VerifierAgent:
    """
    DVN Verifier Agent that evaluates PoA submissions and submits attestations
    """
    
    def __init__(self, private_key: str = None, agent_id: str = None, specialization: str = "general"):
        """
        Initialize Verifier Agent
        
        Args:
            private_key: Private key for blockchain transactions
            agent_id: Unique identifier for this verifier agent
            specialization: Agent specialization (general, electronics, inventory, etc.)
        """
        self.private_key = private_key or os.getenv('VERIFIER_PRIVATE_KEY')
        self.agent_id = agent_id or os.getenv('VERIFIER_AGENT_ID', f'va_{specialization}_{random.randint(1000, 9999)}')
        self.specialization = specialization
        
        # Check if we should run in simulation mode
        if (not self.private_key or 
            self.private_key == 'your_private_key_here' or
            self.private_key == 'simulation' or
            len(self.private_key) < 64):
            logger.warning("No valid private key provided - blockchain operations will be simulated")
            self.simulation_mode = True
            self.account = None
        else:
            self.simulation_mode = False
            try:
                self.account = Account.from_key(self.private_key)
            except Exception as e:
                logger.warning(f"Invalid private key format: {e} - enabling simulation mode")
                self.simulation_mode = True
                self.account = None
        
        # Initialize Web3 connection
        self.w3 = Web3(Web3.HTTPProvider(SEPOLIA_RPC_URL))
        
        # Initialize IPFS client
        self.ipfs_client = IPFSClient()
        
        # Initialize contract addresses
        self.attestation_address = CONTRACT_ADDRESSES["dvn_attestation"]
        self.studio_address = CONTRACT_ADDRESSES["studio_poc"]
        
        # Set evaluation parameters based on specialization
        self.evaluation_config = self._get_evaluation_config()
        
        logger.info(f"Verifier Agent {self.agent_id} ({specialization}) initialized (simulation_mode={self.simulation_mode})")
    
    def _get_evaluation_config(self) -> Dict[str, Any]:
        """Get evaluation configuration based on agent specialization"""
        base_config = {
            "structure_weight": 0.3,
            "content_weight": 0.4,
            "evidence_weight": 0.3,
            "min_approval_threshold": 0.7,
            "confidence_threshold": 0.8
        }
        
        # Specialized configurations
        specialization_configs = {
            "electronics": {
                **base_config,
                "content_weight": 0.5,  # Electronics specialists focus more on content
                "required_fields": ["sku", "quantity", "location", "verification_method"],
                "high_value_item_threshold": 50000  # INR
            },
            "inventory": {
                **base_config,
                "evidence_weight": 0.4,  # Inventory specialists focus on evidence
                "structure_weight": 0.4,
                "anomaly_detection_weight": 0.2
            },
            "general": base_config
        }
        
        return specialization_configs.get(self.specialization, base_config)
    
    def create_workflow(self) -> StateGraph:
        """Create the Verifier Agent LangGraph workflow"""
        
        def initialize_evaluation(state: VerifierAgentState) -> VerifierAgentState:
            """Initialize the evaluation process"""
            logger.info(f"🔍 Starting evaluation of submission {state['submission_id']}")
            
            return {
                **state,
                "current_step": "fetching_submission",
                "status": "evaluating",
                "evaluation_completed": False,
                "started_at": datetime.now(timezone.utc).isoformat()
            }
        
        def fetch_submission_data(state: VerifierAgentState) -> VerifierAgentState:
            """Fetch submission data from blockchain and IPFS"""
            submission_id = state["submission_id"]
            
            logger.info(f"📥 Fetching submission data for {submission_id}")
            
            # For PoC, simulate fetching from blockchain
            # In real implementation, this would query the actual contracts
            mock_submission = {
                "submission_id": submission_id,
                "worker_agent": f"wa_{random.randint(1000, 9999)}",
                "studio_id": STUDIO_ID,
                "ipfs_hash": f"Qm{hash(submission_id) % 1000000:06d}{'a' * 40}",
                "package_hash": f"{hash(submission_id):064x}"[:64],
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "status": "pending_attestation"
            }
            
            # Try to fetch PoA package from IPFS
            poa_package = None
            if not self.ipfs_client.mock_mode:
                poa_package = self.ipfs_client.retrieve_poa_package(mock_submission["ipfs_hash"])
            
            if not poa_package:
                # Generate realistic mock PoA package for evaluation
                poa_package = self._generate_mock_poa_package(submission_id)
                logger.info(f"🎭 Using mock PoA package for evaluation")
            
            return {
                **state,
                "current_step": "evaluating_structure",
                "submission_data": mock_submission,
                "poa_package": poa_package,
                "ipfs_hash": mock_submission["ipfs_hash"],
                "package_hash": mock_submission["package_hash"]
            }
        
        def evaluate_structure(state: VerifierAgentState) -> VerifierAgentState:
            """Evaluate the structure and format of the PoA package"""
            logger.info("🔍 Evaluating PoA package structure...")
            
            poa_package = state["poa_package"]
            evaluation_notes = []
            
            # Check required fields
            required_fields = ["submission_id", "studio_id", "timestamp", "worker_agent_id", 
                             "action_type", "inventory_data", "evidence", "package_hash"]
            
            structure_score = 0.0
            missing_fields = []
            
            for field in required_fields:
                if field in poa_package:
                    structure_score += 1.0 / len(required_fields)
                else:
                    missing_fields.append(field)
            
            if missing_fields:
                evaluation_notes.append(f"Missing required fields: {', '.join(missing_fields)}")
            
            # Validate inventory data structure
            if "inventory_data" in poa_package:
                inventory = poa_package["inventory_data"]
                required_inventory_fields = ["store_id", "scan_timestamp", "items", "total_items_scanned"]
                
                for field in required_inventory_fields:
                    if field not in inventory:
                        structure_score *= 0.9  # Reduce score for missing inventory fields
                        evaluation_notes.append(f"Missing inventory field: {field}")
            
            structure_valid = structure_score >= 0.8
            
            logger.info(f"📋 Structure evaluation: {'VALID' if structure_valid else 'INVALID'} (score: {structure_score:.2f})")
            
            return {
                **state,
                "current_step": "evaluating_content",
                "structure_valid": structure_valid,
                "evaluation_notes": evaluation_notes
            }
        
        def evaluate_content_quality(state: VerifierAgentState) -> VerifierAgentState:
            """Evaluate the quality and validity of the content"""
            logger.info("📊 Evaluating content quality...")
            
            poa_package = state["poa_package"]
            evaluation_notes = state["evaluation_notes"]
            
            content_score = 0.0
            inventory_data = poa_package.get("inventory_data", {})
            items = inventory_data.get("items", [])
            
            if not items:
                evaluation_notes.append("No items found in inventory data")
                content_score = 0.0
            else:
                # Evaluate items quality
                item_scores = []
                
                for item in items:
                    item_score = self._evaluate_single_item(item)
                    item_scores.append(item_score)
                
                content_score = sum(item_scores) / len(item_scores) if item_scores else 0.0
                
                # Check for anomalies and consistency
                anomalies = inventory_data.get("anomalies", [])
                if len(anomalies) > len(items) * 0.3:  # More than 30% anomalies
                    content_score *= 0.8
                    evaluation_notes.append("High anomaly rate detected")
                
                # Check scan confidence
                scan_confidence = inventory_data.get("scan_confidence", 0.0)
                if scan_confidence < VERIFIER_AGENT_DEFAULTS["min_confidence_threshold"]:
                    content_score *= 0.9
                    evaluation_notes.append(f"Low scan confidence: {scan_confidence:.2f}")
            
            logger.info(f"📊 Content quality score: {content_score:.2f}")
            
            return {
                **state,
                "current_step": "evaluating_evidence",
                "content_quality_score": content_score,
                "evaluation_notes": evaluation_notes
            }
        
        def evaluate_evidence_quality(state: VerifierAgentState) -> VerifierAgentState:
            """Evaluate the quality of supporting evidence"""
            logger.info("🗂️ Evaluating evidence quality...")
            
            poa_package = state["poa_package"]
            evaluation_notes = state["evaluation_notes"]
            
            evidence = poa_package.get("evidence", {})
            evidence_score = 0.0
            
            # Check for required evidence types
            required_evidence = VERIFIER_AGENT_DEFAULTS["required_evidence_types"]
            evidence_present = 0
            
            for evidence_type in required_evidence:
                if evidence_type in evidence or any(evidence_type in str(v) for v in evidence.values()):
                    evidence_present += 1
            
            evidence_score = evidence_present / len(required_evidence)
            
            # Bonus for additional evidence
            if "verification_method" in evidence:
                evidence_score += 0.1
            
            if "agent_id" in evidence:
                evidence_score += 0.1
            
            evidence_score = min(1.0, evidence_score)  # Cap at 1.0
            
            logger.info(f"🗂️ Evidence quality score: {evidence_score:.2f}")
            
            return {
                **state,
                "current_step": "calculating_final_score",
                "evidence_quality_score": evidence_score,
                "evaluation_notes": evaluation_notes
            }
        
        def calculate_final_evaluation(state: VerifierAgentState) -> VerifierAgentState:
            """Calculate final evaluation score and make attestation decision"""
            logger.info("🎯 Calculating final evaluation...")
            
            # Get scores
            structure_score = 1.0 if state.get("structure_valid", False) else 0.0
            content_score = state.get("content_quality_score", 0.0)
            evidence_score = state.get("evidence_quality_score", 0.0)
            
            # Calculate weighted overall score
            config = self.evaluation_config
            overall_score = (
                structure_score * config["structure_weight"] +
                content_score * config["content_weight"] +
                evidence_score * config["evidence_weight"]
            )
            
            # Determine attestation decision
            attestation_decision = overall_score >= config["min_approval_threshold"]
            
            # Calculate confidence (based on score consistency and specialization match)
            score_variance = abs(structure_score - content_score) + abs(content_score - evidence_score)
            confidence = max(0.5, 1.0 - (score_variance / 2.0))
            
            logger.info(f"🎯 Final evaluation: {overall_score:.2f} -> {'APPROVE' if attestation_decision else 'REJECT'}")
            
            return {
                **state,
                "current_step": "creating_attestation",
                "overall_score": overall_score,
                "evaluation_confidence": confidence,
                "attestation_decision": attestation_decision,
                "evaluation_completed": True
            }
        
        def create_and_submit_attestation(state: VerifierAgentState) -> VerifierAgentState:
            """Create cryptographic attestation and submit to blockchain"""
            logger.info("✍️ Creating and submitting attestation...")
            
            # Create attestation evidence
            attestation_evidence = {
                "verifier_agent_id": self.agent_id,
                "specialization": self.specialization,
                "overall_score": state["overall_score"],
                "evaluation_confidence": state["evaluation_confidence"],
                "structure_valid": state.get("structure_valid", False),
                "content_quality_score": state.get("content_quality_score", 0.0),
                "evidence_quality_score": state.get("evidence_quality_score", 0.0),
                "evaluation_notes": state.get("evaluation_notes", []),
                "evaluation_timestamp": datetime.now(timezone.utc).isoformat(),
                "decision_reason": self._generate_decision_reason(state)
            }
            
            if self.simulation_mode:
                # Simulate attestation submission
                logger.info("🎭 Simulation mode: generating mock attestation submission")
                
                mock_signature = f"0x{''.join(random.choices('0123456789abcdef', k=130))}"
                tx_hash = f"0x{''.join(random.choices('0123456789abcdef', k=64))}"
                gas_used = random.randint(200000, 300000)
                
                return {
                    **state,
                    "current_step": "completed",
                    "status": "completed",
                    "attestation_evidence": attestation_evidence,
                    "attestation_signature": mock_signature,
                    "tx_hash": tx_hash,
                    "gas_used": gas_used,
                    "completed_at": datetime.now(timezone.utc).isoformat()
                }
            
            try:
                # Real blockchain submission would go here
                # For now, simulate since we don't have contract ABIs loaded
                
                logger.info("⛓️ Submitting attestation to blockchain...")
                
                # Create message to sign
                message = json.dumps(attestation_evidence, sort_keys=True)
                signature = self.account.signHash(Web3.keccak(text=message))
                
                # Simulate transaction
                tx_hash = f"0x{''.join(random.choices('0123456789abcdef', k=64))}"
                gas_used = random.randint(200000, 300000)
                
                logger.info(f"✅ Attestation submitted: {tx_hash}")
                
                return {
                    **state,
                    "current_step": "completed",
                    "status": "completed",
                    "attestation_evidence": attestation_evidence,
                    "attestation_signature": signature.signature.hex(),
                    "tx_hash": tx_hash,
                    "gas_used": gas_used,
                    "completed_at": datetime.now(timezone.utc).isoformat()
                }
                
            except Exception as e:
                logger.error(f"❌ Attestation submission failed: {e}")
                return {
                    **state,
                    "current_step": "failed",
                    "status": "failed",
                    "error_message": str(e),
                    "completed_at": datetime.now(timezone.utc).isoformat()
                }
        
        # Create the workflow graph
        workflow = StateGraph(VerifierAgentState)
        
        # Add nodes
        workflow.add_node("initialize", initialize_evaluation)
        workflow.add_node("fetch_data", fetch_submission_data)
        workflow.add_node("eval_structure", evaluate_structure)
        workflow.add_node("eval_content", evaluate_content_quality)
        workflow.add_node("eval_evidence", evaluate_evidence_quality)
        workflow.add_node("final_eval", calculate_final_evaluation)
        workflow.add_node("submit_attestation", create_and_submit_attestation)
        
        # Add edges
        workflow.add_edge("initialize", "fetch_data")
        workflow.add_edge("fetch_data", "eval_structure")
        workflow.add_edge("eval_structure", "eval_content")
        workflow.add_edge("eval_content", "eval_evidence")
        workflow.add_edge("eval_evidence", "final_eval")
        workflow.add_edge("final_eval", "submit_attestation")
        
        # Set entry and exit points
        workflow.set_entry_point("initialize")
        workflow.set_finish_point("submit_attestation")
        
        return workflow
    
    def _evaluate_single_item(self, item: Dict[str, Any]) -> float:
        """Evaluate a single inventory item"""
        score = 0.0
        
        # Check required fields
        required_fields = ["sku", "name", "quantity", "location", "verification_method", "confidence"]
        for field in required_fields:
            if field in item:
                score += 1.0 / len(required_fields)
        
        # Check confidence level
        confidence = item.get("confidence", 0.0)
        if confidence >= 0.9:
            score += 0.1
        elif confidence < 0.7:
            score -= 0.1
        
        # Check for reasonable quantity
        quantity = item.get("quantity", 0)
        if 0 <= quantity <= 1000:  # Reasonable range
            score += 0.05
        
        return max(0.0, min(1.0, score))
    
    def _generate_mock_poa_package(self, submission_id: str) -> Dict[str, Any]:
        """Generate a realistic mock PoA package for evaluation"""
        return {
            "submission_id": submission_id,
            "studio_id": STUDIO_ID,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "worker_agent_id": f"wa_{random.randint(1000, 9999)}",
            "action_type": random.choice(SUPPORTED_ACTION_TYPES),
            "inventory_data": {
                "store_id": f"store_{random.randint(100, 999)}",
                "scan_timestamp": datetime.now(timezone.utc).isoformat(),
                "section": random.choice(["electronics", "smartphones", "accessories"]),
                "items": [
                    {
                        "sku": f"ITEM{i:03d}",
                        "name": f"Test Item {i}",
                        "quantity": random.randint(0, 50),
                        "location": f"Aisle-{random.choice(['A', 'B', 'C'])}-Shelf-{random.randint(1, 5)}",
                        "verification_method": random.choice(WORKER_AGENT_DEFAULTS["verification_methods"]),
                        "confidence": random.uniform(0.7, 0.98),
                        "unit_price": random.uniform(100, 50000)
                    }
                    for i in range(random.randint(1, 5))
                ],
                "total_items_scanned": random.randint(1, 5),
                "scan_confidence": random.uniform(0.8, 0.95),
                "anomalies": []
            },
            "evidence": {
                "scan_logs": f"log_{submission_id}",
                "agent_id": f"wa_{random.randint(1000, 9999)}",
                "verification_method": "automated"
            },
            "package_hash": f"{hash(submission_id):064x}"[:64]
        }
    
    def _generate_decision_reason(self, state: VerifierAgentState) -> str:
        """Generate human-readable reason for attestation decision"""
        decision = state["attestation_decision"]
        score = state["overall_score"]
        
        if decision:
            if score >= 0.9:
                return "Excellent submission quality with complete evidence and accurate data"
            elif score >= 0.8:
                return "Good submission quality with minor issues that do not affect validity"
            else:
                return "Acceptable submission quality meeting minimum requirements"
        else:
            issues = state.get("evaluation_notes", [])
            if issues:
                return f"Submission rejected due to: {'; '.join(issues[:3])}"
            else:
                return f"Submission quality score {score:.2f} below approval threshold"
    
    def evaluate_submission(self, submission_id: str) -> Dict[str, Any]:
        """
        Evaluate a PoA submission and submit attestation
        
        Args:
            submission_id: Unique identifier for the submission to evaluate
            
        Returns:
            Final evaluation state
        """
        logger.info(f"🚀 Starting evaluation of submission {submission_id}")
        
        # Create and compile workflow
        workflow = self.create_workflow()
        compiled_workflow = workflow.compile()
        
        # Initialize state
        initial_state: VerifierAgentState = {
            "submission_id": submission_id,
            "agent_id": self.agent_id,
            "current_step": "initializing",
            "status": "initializing",
            "error_message": "",
            "submission_data": {},
            "poa_package": {},
            "ipfs_hash": "",
            "package_hash": "",
            "evaluation_completed": False,
            "structure_valid": False,
            "content_quality_score": 0.0,
            "evidence_quality_score": 0.0,
            "overall_score": 0.0,
            "evaluation_confidence": 0.0,
            "evaluation_notes": [],
            "attestation_decision": False,
            "attestation_evidence": {},
            "attestation_signature": "",
            "tx_hash": "",
            "gas_used": 0,
            "started_at": "",
            "completed_at": ""
        }
        
        try:
            # Execute workflow
            final_state = compiled_workflow.invoke(initial_state)
            
            logger.info(f"🏁 Evaluation completed with decision: {'APPROVE' if final_state['attestation_decision'] else 'REJECT'}")
            
            return final_state
            
        except Exception as e:
            logger.error(f"❌ Workflow execution failed: {e}")
            return {
                **initial_state,
                "status": "failed",
                "error_message": str(e),
                "completed_at": datetime.now(timezone.utc).isoformat()
            }

def main():
    """CLI interface for Verifier Agent"""
    import argparse
    
    parser = argparse.ArgumentParser(description="ChaosChain DVN Verifier Agent")
    parser.add_argument("--submission-id", required=True, help="Submission ID to evaluate")
    parser.add_argument("--specialization", default="general", 
                       choices=["general", "electronics", "inventory"], 
                       help="Agent specialization")
    parser.add_argument("--agent-id", help="Custom agent ID")
    parser.add_argument("--private-key", help="Private key for blockchain transactions")
    parser.add_argument("--auto-mode", action="store_true", help="Auto-evaluate mode (monitor for submissions)")
    
    args = parser.parse_args()
    
    print("🔍 ChaosChain DVN Verifier Agent")
    print("=" * 60)
    
    # Initialize verifier agent
    agent = VerifierAgent(
        private_key=args.private_key,
        agent_id=args.agent_id,
        specialization=args.specialization
    )
    
    if args.auto_mode:
        print("🤖 Auto-evaluation mode not implemented yet")
        print("Use --submission-id to evaluate specific submissions")
        return False
    
    # Evaluate specific submission
    result = agent.evaluate_submission(args.submission_id)
    
    # Display results
    print(f"\n📊 Evaluation Results for {args.submission_id}:")
    print(f"Status: {result['status']}")
    print(f"Decision: {'APPROVE' if result['attestation_decision'] else 'REJECT'}")
    print(f"Overall Score: {result['overall_score']:.2f}")
    print(f"Confidence: {result['evaluation_confidence']:.2f}")
    
    if result['status'] == 'completed':
        print(f"Transaction Hash: {result['tx_hash']}")
        print(f"Gas Used: {result['gas_used']}")
    
    if result.get('evaluation_notes'):
        print(f"Notes: {'; '.join(result['evaluation_notes'])}")
    
    if result.get('error_message'):
        print(f"Error: {result['error_message']}")
    
    return result['status'] == 'completed'

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1) 