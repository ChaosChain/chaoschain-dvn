"""
Shared constants for ChaosChain DVN PoC agents
Centralized configuration to avoid code duplication
"""

import os
from typing import Dict, List
from web3 import Web3

# ==========================================
# BLOCKCHAIN CONFIGURATION
# ==========================================

# Sepolia testnet configuration
SEPOLIA_CHAIN_ID = 11155111
SEPOLIA_RPC_URL = "https://eth-sepolia.g.alchemy.com/v2/gkHpxu7aSBljCv8Hlxu1GJnQRsyyZM7z"

# Contract addresses (from Phase 1 deployment)
CONTRACT_ADDRESSES = {
    "dvn_registry": "0x5A6207a71c49037316aD1C37E26df2E40aB599fE",
    "dvn_attestation": "0x950B75d0769dfC164f030976cEAd4C89BCA5541F", 
    "dvn_consensus": "0x33807533035915AA6A461E4d0c7b136Ea0771dDa",
    "studio_poc": "0x03ed96a2543deaAfD9537107bFE017e5Acac40De"
}

# Gas configuration for transactions
GAS_LIMITS = {
    "register_agent": 200000,
    "submit_poa": 300000,
    "submit_attestation": 250000,
    "process_consensus": 400000
}

# Transaction settings
MAX_GAS_PRICE_GWEI = 50
TX_TIMEOUT_SECONDS = 120
CONFIRMATION_BLOCKS = 1

# ==========================================
# STUDIO CONFIGURATION
# ==========================================

# KiranaAI Studio specific settings
STUDIO_ID = "kirana_ai_poc"
SUPPORTED_ACTION_TYPES = [
    "KiranaAI_StockReport",
    "KiranaAI_InventoryAudit", 
    "KiranaAI_ReorderAlert"
]

# Verification fee in ETH
VERIFICATION_FEE_ETH = 0.0001

# Staking requirements for Verifier Agents
MIN_STAKE_ETH = 0.001
REPUTATION_WEIGHT = 1000  # Default reputation score

# ==========================================
# IPFS CONFIGURATION  
# ==========================================

# IPFS settings
IPFS_NODE_URL = os.getenv('IPFS_NODE_URL', '/ip4/127.0.0.1/tcp/5001')
IPFS_GATEWAY_URL = "https://ipfs.io/ipfs/"
IPFS_PIN_ON_UPLOAD = True

# PoA package configuration
POA_PACKAGE_VERSION = "1.0"
POA_SCHEMA_VERSION = "poa-package-v1"

# ==========================================
# AGENT CONFIGURATION
# ==========================================

# Worker Agent settings
WORKER_AGENT_DEFAULTS = {
    "scan_duration_minutes": 15,
    "confidence_threshold": 0.8,
    "max_items_per_scan": 1000,
    "evidence_photo_count": 3,
    "verification_methods": ["barcode_scan", "visual_inspection", "rfid_scan"]
}

# Verifier Agent settings  
VERIFIER_AGENT_DEFAULTS = {
    "evaluation_timeout_minutes": 5,
    "min_confidence_threshold": 0.7,
    "required_evidence_types": ["scan_logs", "item_list"],
    "consensus_participation_rate": 0.9
}

# Consensus parameters (matching smart contract)
CONSENSUS_CONFIG = {
    "min_attestation_period_minutes": 3,
    "consensus_threshold_percent": 66,
    "max_consensus_timeout_minutes": 10,
    "min_verifier_agents": 3
}

# ==========================================
# INVENTORY SIMULATION DATA
# ==========================================

# Sample inventory data for testing
SAMPLE_STORES = [
    {
        "store_id": "store_123",
        "name": "Electronics Superstore",
        "location": "Mumbai Central",
        "sections": ["electronics", "accessories", "gaming"]
    },
    {
        "store_id": "store_456", 
        "name": "Mobile World",
        "location": "Delhi CP",
        "sections": ["smartphones", "tablets", "wearables"]
    }
]

SAMPLE_INVENTORY_ITEMS = [
    {
        "sku": "LAPTOP001",
        "name": "Gaming Laptop Dell G15",
        "category": "electronics",
        "unit_price": 85000.00,
        "typical_quantity": 8
    },
    {
        "sku": "PHONE001",
        "name": "iPhone 15 Pro Max",
        "category": "smartphones", 
        "unit_price": 159900.00,
        "typical_quantity": 15
    },
    {
        "sku": "TABLET001",
        "name": "iPad Air M2",
        "category": "tablets",
        "unit_price": 59900.00,
        "typical_quantity": 12
    },
    {
        "sku": "WATCH001",
        "name": "Apple Watch Series 9",
        "category": "wearables",
        "unit_price": 41900.00,
        "typical_quantity": 20
    },
    {
        "sku": "HEADPHONE001", 
        "name": "Sony WH-1000XM5",
        "category": "accessories",
        "unit_price": 29990.00,
        "typical_quantity": 25
    }
]

# ==========================================
# LOGGING AND MONITORING
# ==========================================

# Logging configuration
LOG_LEVEL = os.getenv('LOG_LEVEL', 'INFO')
LOG_FORMAT = '%(asctime)s - %(name)s - %(levelname)s - %(message)s'

# Monitoring intervals
HEALTH_CHECK_INTERVAL_MINUTES = 5
STATUS_UPDATE_INTERVAL_MINUTES = 2
METRICS_COLLECTION_INTERVAL_MINUTES = 10

# ==========================================
# LANGGRAPH AGENT CONFIGURATION
# ==========================================

# LangGraph workflow configuration
AGENT_WORKFLOW_CONFIG = {
    "max_execution_time": 600,  # 10 minutes max per workflow
    "checkpoint_interval": 30,   # Save state every 30 seconds
    "retry_attempts": 3,
    "backoff_multiplier": 2
}

# LLM Model configuration (for AI evaluation)
LLM_CONFIG = {
    "model_name": "anthropic:claude-3-7-sonnet-latest",
    "max_tokens": 4000,
    "temperature": 0.1,  # Low temperature for consistent evaluation
    "timeout": 30
}

# Agent state management
AGENT_STATES = [
    "idle",
    "scanning", 
    "uploading",
    "submitting",
    "evaluating",
    "attesting", 
    "completed",
    "error"
]

# ==========================================
# UTILITY FUNCTIONS
# ==========================================

def wei_to_eth(wei_amount: int) -> float:
    """Convert Wei to ETH"""
    return Web3.from_wei(wei_amount, 'ether')

def eth_to_wei(eth_amount: float) -> int:
    """Convert ETH to Wei"""
    return Web3.to_wei(eth_amount, 'ether')

def get_contract_address(contract_name: str) -> str:
    """Get contract address by name"""
    return CONTRACT_ADDRESSES.get(contract_name.lower().replace('poc', '').replace('_', ''))

def get_gas_limit(operation: str) -> int:
    """Get gas limit for operation"""
    return GAS_LIMITS.get(operation, 200000)

def is_valid_action_type(action_type: str) -> bool:
    """Check if action type is supported by KiranaAI Studio"""
    return action_type in SUPPORTED_ACTION_TYPES

# Environment validation
def validate_environment():
    """Validate required environment variables and configuration"""
    required_env_vars = [
        'PRIVATE_KEY',  # For signing transactions
    ]
    
    missing_vars = [var for var in required_env_vars if not os.getenv(var)]
    if missing_vars:
        raise ValueError(f"Missing required environment variables: {missing_vars}")
    
    # Validate contract addresses
    for name, address in CONTRACT_ADDRESSES.items():
        if not Web3.is_address(address):
            raise ValueError(f"Invalid contract address for {name}: {address}")
    
    print("✅ Environment validation passed")

if __name__ == "__main__":
    # Test configuration
    print("ChaosChain DVN PoC - Configuration Test")
    print("=" * 50)
    
    print(f"🌍 Network: Sepolia (Chain ID: {SEPOLIA_CHAIN_ID})")
    print(f"📋 Studio: {STUDIO_ID}")
    print(f"💰 Verification Fee: {VERIFICATION_FEE_ETH} ETH")
    print(f"🏪 Sample Stores: {len(SAMPLE_STORES)}")
    print(f"📦 Sample Items: {len(SAMPLE_INVENTORY_ITEMS)}")
    
    print("\n📍 Contract Addresses:")
    for name, address in CONTRACT_ADDRESSES.items():
        print(f"  {name}: {address}")
    
    print(f"\n🎯 Supported Actions: {', '.join(SUPPORTED_ACTION_TYPES)}")
    
    try:
        validate_environment()
    except ValueError as e:
        print(f"⚠️  Environment validation warning: {e}")
        print("   Set PRIVATE_KEY environment variable for full functionality")
    
    print("\n✅ Configuration loaded successfully!") 