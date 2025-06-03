"""
ChaosChain DVN PoC - Worker Agent Implementation
Performs inventory verification and submits PoA packages for evaluation
"""

import os
import sys
import json
import logging
import random
from datetime import datetime, timezone
from typing import Dict, Any, List, Optional
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
        logging.FileHandler('logs/worker_agent.log') if os.path.exists('logs') else logging.NullHandler()
    ]
)
logger = logging.getLogger(__name__)

class WorkerAgentState(TypedDict):
    """State schema for Worker Agent workflow"""
    # Input parameters
    store_id: str
    section: str
    action_type: str
    agent_id: str
    
    # Workflow status
    current_step: str
    status: str
    error_message: str
    
    # Inventory scanning results
    scan_completed: bool
    items_scanned: List[Dict[str, Any]]
    total_items: int
    scan_duration: str
    anomalies: List[Dict[str, Any]]
    scan_confidence: float
    
    # PoA package creation
    poa_package: Dict[str, Any]
    package_hash: str
    ipfs_hash: str
    
    # Blockchain submission
    tx_hash: str
    submission_id: int
    gas_used: int
    verification_fee_paid: float
    
    # Timestamps
    started_at: str
    completed_at: str

class WorkerAgent:
    """
    DVN Worker Agent that performs inventory verification and submits PoA packages
    """
    
    def __init__(self, private_key: str = None, agent_id: str = None):
        """
        Initialize Worker Agent
        
        Args:
            private_key: Private key for blockchain transactions
            agent_id: Unique identifier for this worker agent
        """
        self.private_key = private_key or os.getenv('PRIVATE_KEY')
        self.agent_id = agent_id or os.getenv('WORKER_AGENT_ID', f'wa_{random.randint(1000, 9999)}')
        
        # Check if we should run in simulation mode
        if (not self.private_key or 
            self.private_key == 'your_private_key_here' or
            self.private_key == 'simulation' or
            len(self.private_key) < 64):  # Valid Ethereum private keys are 64 hex chars
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
        
        # Initialize contract interfaces (simplified for PoC)
        self.studio_address = CONTRACT_ADDRESSES["studio_poc"]
        
        logger.info(f"Worker Agent {self.agent_id} initialized (simulation_mode={self.simulation_mode})")
    
    def create_workflow(self) -> StateGraph:
        """Create the Worker Agent LangGraph workflow"""
        
        # Define workflow nodes
        def initialize_scan(state: WorkerAgentState) -> WorkerAgentState:
            """Initialize the inventory scanning process"""
            logger.info(f"🏁 Starting inventory scan for store {state['store_id']}")
            
            return {
                **state,
                "current_step": "scanning",
                "status": "scanning",
                "scan_completed": False,
                "started_at": datetime.now(timezone.utc).isoformat()
            }
        
        def perform_inventory_scan(state: WorkerAgentState) -> WorkerAgentState:
            """Simulate inventory scanning process"""
            store_id = state["store_id"]
            section = state["section"]
            
            logger.info(f"📦 Scanning {section} section in {store_id}")
            
            # Simulate scanning process
            scanned_items = self._simulate_inventory_scan(store_id, section)
            scan_duration = f"00:{random.randint(10, 25)}:{random.randint(10, 59)}"
            
            # Calculate confidence based on scan quality
            confidence = self._calculate_scan_confidence(scanned_items)
            
            # Detect anomalies
            anomalies = self._detect_anomalies(scanned_items)
            
            logger.info(f"✅ Scan completed: {len(scanned_items)} items, confidence: {confidence:.2f}")
            
            return {
                **state,
                "current_step": "scan_completed",
                "scan_completed": True,
                "items_scanned": scanned_items,
                "total_items": len(scanned_items),
                "scan_duration": scan_duration,
                "scan_confidence": confidence,
                "anomalies": anomalies
            }
        
        def create_poa_package(state: WorkerAgentState) -> WorkerAgentState:
            """Create PoA package for submission"""
            logger.info("📄 Creating PoA package...")
            
            # Prepare inventory data
            inventory_data = {
                "store_id": state["store_id"],
                "scan_timestamp": datetime.now(timezone.utc).isoformat(),
                "section": state["section"],
                "items": state["items_scanned"],
                "total_items_scanned": state["total_items"],
                "verification_duration": state["scan_duration"],
                "scan_confidence": state["scan_confidence"],
                "anomalies": state["anomalies"],
                "verification_notes": f"Automated scan by {self.agent_id}"
            }
            
            # Create evidence package
            evidence = {
                "scan_logs": f"scan_log_{state['store_id']}_{datetime.now().strftime('%Y%m%d_%H%M%S')}",
                "verification_method": "automated_barcode_scan",
                "agent_id": self.agent_id,
                "scan_metadata": {
                    "confidence_threshold": WORKER_AGENT_DEFAULTS["confidence_threshold"],
                    "scan_method": "simulated"
                }
            }
            
            # Generate unique submission ID
            submission_id = f"{state['store_id']}_{state['action_type']}_{int(datetime.now().timestamp())}"
            
            # Create PoA package
            poa_package = self.ipfs_client.create_poa_package(
                submission_id=submission_id,
                studio_id=STUDIO_ID,
                worker_agent_id=self.agent_id,
                action_type=state["action_type"],
                inventory_data=inventory_data,
                evidence=evidence
            )
            
            logger.info(f"📦 PoA package created with hash: {poa_package['package_hash']}")
            
            return {
                **state,
                "current_step": "poa_created",
                "poa_package": poa_package,
                "package_hash": poa_package["package_hash"]
            }
        
        def upload_to_ipfs(state: WorkerAgentState) -> WorkerAgentState:
            """Upload PoA package to IPFS"""
            logger.info("🌐 Uploading PoA package to IPFS...")
            
            # Upload to IPFS
            ipfs_hash = self.ipfs_client.upload_poa_package(state["poa_package"])
            
            if ipfs_hash:
                logger.info(f"✅ Uploaded to IPFS: {ipfs_hash}")
                return {
                    **state,
                    "current_step": "ipfs_uploaded",
                    "ipfs_hash": ipfs_hash
                }
            else:
                logger.warning("⚠️ IPFS upload failed - using package hash as fallback")
                return {
                    **state,
                    "current_step": "ipfs_failed",
                    "ipfs_hash": state["package_hash"],  # Fallback to package hash
                    "error_message": "IPFS upload failed, using local hash"
                }
        
        def submit_to_blockchain(state: WorkerAgentState) -> WorkerAgentState:
            """Submit PoA to blockchain via Studio contract"""
            logger.info("⛓️ Submitting PoA to blockchain...")
            
            if self.simulation_mode:
                # Simulate blockchain submission
                logger.info("🎭 Simulation mode: generating mock transaction")
                
                tx_hash = f"0x{''.join(random.choices('0123456789abcdef', k=64))}"
                submission_id = random.randint(1000, 9999)
                gas_used = random.randint(250000, 350000)
                
                return {
                    **state,
                    "current_step": "submitted",
                    "status": "submitted",
                    "tx_hash": tx_hash,
                    "submission_id": submission_id,
                    "gas_used": gas_used,
                    "verification_fee_paid": VERIFICATION_FEE_ETH,
                    "completed_at": datetime.now(timezone.utc).isoformat()
                }
            
            try:
                # Real blockchain submission
                package_hash_bytes = bytes.fromhex(state["package_hash"])
                ipfs_hash = state["ipfs_hash"]
                studio_address = self.studio_address
                
                # Prepare transaction data (simplified for PoC)
                # In real implementation, this would use the actual contract ABI
                transaction = {
                    'to': studio_address,
                    'value': self.w3.to_wei(VERIFICATION_FEE_ETH, 'ether'),
                    'gas': GAS_LIMITS["submit_poa"],
                    'gasPrice': self.w3.to_wei(20, 'gwei'),
                    'nonce': self.w3.eth.get_transaction_count(self.account.address),
                    'data': f"0x{package_hash_bytes.hex()}"  # Simplified data
                }
                
                # Sign and send transaction
                signed_txn = self.w3.eth.account.sign_transaction(transaction, self.private_key)
                tx_hash = self.w3.eth.send_raw_transaction(signed_txn.rawTransaction)
                
                # Wait for confirmation
                receipt = self.w3.eth.wait_for_transaction_receipt(tx_hash, timeout=TX_TIMEOUT_SECONDS)
                
                logger.info(f"✅ Transaction confirmed: {tx_hash.hex()}")
                
                return {
                    **state,
                    "current_step": "submitted",
                    "status": "submitted",
                    "tx_hash": tx_hash.hex(),
                    "submission_id": receipt['blockNumber'],  # Simplified
                    "gas_used": receipt['gasUsed'],
                    "verification_fee_paid": VERIFICATION_FEE_ETH,
                    "completed_at": datetime.now(timezone.utc).isoformat()
                }
                
            except Exception as e:
                logger.error(f"❌ Blockchain submission failed: {e}")
                return {
                    **state,
                    "current_step": "failed",
                    "status": "failed",
                    "error_message": str(e)
                }
        
        # Create the workflow graph
        workflow = StateGraph(WorkerAgentState)
        
        # Add nodes
        workflow.add_node("initialize", initialize_scan)
        workflow.add_node("scan", perform_inventory_scan)
        workflow.add_node("create_poa", create_poa_package)
        workflow.add_node("upload", upload_to_ipfs)
        workflow.add_node("submit", submit_to_blockchain)
        
        # Add edges
        workflow.add_edge("initialize", "scan")
        workflow.add_edge("scan", "create_poa")
        workflow.add_edge("create_poa", "upload")
        workflow.add_edge("upload", "submit")
        
        # Set entry and exit points
        workflow.set_entry_point("initialize")
        workflow.set_finish_point("submit")
        
        return workflow
    
    def _simulate_inventory_scan(self, store_id: str, section: str) -> List[Dict[str, Any]]:
        """Simulate inventory scanning for a store section"""
        
        # Filter items by section
        available_items = [
            item for item in SAMPLE_INVENTORY_ITEMS 
            if section.lower() in item["category"].lower()
        ]
        
        # If no items match, use all items
        if not available_items:
            available_items = SAMPLE_INVENTORY_ITEMS
        
        scanned_items = []
        
        # Simulate scanning each item type with quantity variations
        for item_template in available_items:
            # Random quantity variation (±20% of typical)
            base_qty = item_template["typical_quantity"]
            variation = random.randint(-int(base_qty * 0.2), int(base_qty * 0.2))
            actual_qty = max(0, base_qty + variation)
            
            # Simulate confidence based on scan method
            confidence = random.uniform(0.85, 0.98)
            
            scanned_item = {
                "sku": item_template["sku"],
                "name": item_template["name"],
                "category": item_template["category"],
                "quantity": actual_qty,
                "unit_price": item_template["unit_price"],
                "location": f"Aisle-{random.choice(['A', 'B', 'C'])}-Shelf-{random.randint(1, 5)}",
                "verification_method": random.choice(WORKER_AGENT_DEFAULTS["verification_methods"]),
                "confidence": confidence,
                "scan_timestamp": datetime.now(timezone.utc).isoformat()
            }
            
            scanned_items.append(scanned_item)
        
        return scanned_items
    
    def _calculate_scan_confidence(self, items: List[Dict[str, Any]]) -> float:
        """Calculate overall scan confidence"""
        if not items:
            return 0.0
        
        confidences = [item.get("confidence", 0.8) for item in items]
        return sum(confidences) / len(confidences)
    
    def _detect_anomalies(self, items: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Detect potential inventory anomalies"""
        anomalies = []
        
        for item in items:
            # Low quantity anomaly
            if item["quantity"] == 0:
                anomalies.append({
                    "type": "out_of_stock",
                    "sku": item["sku"],
                    "description": f"Item {item['name']} is out of stock",
                    "severity": "high"
                })
            
            # Low confidence anomaly
            if item["confidence"] < WORKER_AGENT_DEFAULTS["confidence_threshold"]:
                anomalies.append({
                    "type": "low_confidence",
                    "sku": item["sku"],
                    "description": f"Low scan confidence: {item['confidence']:.2f}",
                    "severity": "medium"
                })
        
        return anomalies
    
    def execute_verification(self, store_id: str, section: str = "electronics", 
                           action_type: str = "KiranaAI_StockReport") -> Dict[str, Any]:
        """
        Execute complete inventory verification workflow
        
        Args:
            store_id: Store identifier
            section: Store section to scan
            action_type: Type of verification action
            
        Returns:
            Final workflow state
        """
        logger.info(f"🚀 Starting inventory verification for {store_id}/{section}")
        
        # Validate action type
        if not is_valid_action_type(action_type):
            raise ValueError(f"Invalid action type: {action_type}. Must be one of: {SUPPORTED_ACTION_TYPES}")
        
        # Create and compile workflow
        workflow = self.create_workflow()
        compiled_workflow = workflow.compile()
        
        # Initialize state
        initial_state: WorkerAgentState = {
            "store_id": store_id,
            "section": section,
            "action_type": action_type,
            "agent_id": self.agent_id,
            "current_step": "initializing",
            "status": "initializing",
            "error_message": "",
            "scan_completed": False,
            "items_scanned": [],
            "total_items": 0,
            "scan_duration": "",
            "anomalies": [],
            "scan_confidence": 0.0,
            "poa_package": {},
            "package_hash": "",
            "ipfs_hash": "",
            "tx_hash": "",
            "submission_id": 0,
            "gas_used": 0,
            "verification_fee_paid": 0.0,
            "started_at": "",
            "completed_at": ""
        }
        
        try:
            # Execute workflow
            final_state = compiled_workflow.invoke(initial_state)
            
            logger.info(f"🏁 Verification completed with status: {final_state['status']}")
            
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
    """CLI interface for Worker Agent"""
    import argparse
    
    parser = argparse.ArgumentParser(description="ChaosChain DVN Worker Agent")
    parser.add_argument("--store-id", default="store_123", help="Store ID to scan")
    parser.add_argument("--section", default="electronics", help="Store section to scan")
    parser.add_argument("--action-type", default="KiranaAI_StockReport", 
                       choices=SUPPORTED_ACTION_TYPES, help="Type of verification action")
    parser.add_argument("--agent-id", help="Custom agent ID")
    parser.add_argument("--private-key", help="Private key for blockchain transactions")
    
    args = parser.parse_args()
    
    print("🤖 ChaosChain DVN Worker Agent")
    print("=" * 50)
    
    # Initialize worker agent
    agent = WorkerAgent(
        private_key=args.private_key,
        agent_id=args.agent_id
    )
    
    # Execute verification
    result = agent.execute_verification(
        store_id=args.store_id,
        section=args.section,
        action_type=args.action_type
    )
    
    # Display results
    print("\n📊 Verification Results:")
    print(f"Status: {result['status']}")
    print(f"Items Scanned: {result['total_items']}")
    print(f"Scan Confidence: {result['scan_confidence']:.2f}")
    print(f"Anomalies: {len(result['anomalies'])}")
    
    if result['status'] == 'submitted':
        print(f"Transaction Hash: {result['tx_hash']}")
        print(f"Submission ID: {result['submission_id']}")
        print(f"IPFS Hash: {result['ipfs_hash']}")
    
    if result.get('error_message'):
        print(f"Error: {result['error_message']}")
    
    return result['status'] == 'submitted'

if __name__ == "__main__":
    success = main()
    exit(0 if success else 1) 