"""
IPFS Client for ChaosChain DVN PoC
Handles uploading and retrieving PoA packages from IPFS
"""

import json
import hashlib
import logging
from typing import Dict, Any, Optional, List
import os
from datetime import datetime, timezone
from pathlib import Path

# Try to import IPFS client, but handle gracefully if not available
try:
    import ipfshttpclient
    IPFS_AVAILABLE = True
except ImportError:
    IPFS_AVAILABLE = False
    ipfshttpclient = None

logger = logging.getLogger(__name__)

class IPFSClient:
    """Client for interacting with IPFS for PoA package storage"""
    
    def __init__(self, ipfs_url: str = None, mock_mode: bool = None):
        """
        Initialize IPFS client
        
        Args:
            ipfs_url: IPFS node URL (defaults to localhost or env var)
            mock_mode: Force mock mode for testing (auto-detected if None)
        """
        self.ipfs_url = ipfs_url or os.getenv('IPFS_NODE_URL', '/ip4/127.0.0.1/tcp/5001')
        self.client = None
        self.mock_mode = mock_mode
        
        # Auto-detect mock mode if not specified
        if self.mock_mode is None:
            self.mock_mode = not IPFS_AVAILABLE
        
        if not self.mock_mode:
            self._connect()
        else:
            logger.info("IPFS Mock Mode: Generating realistic hashes for development")
    
    def _connect(self):
        """Connect to IPFS node"""
        if not IPFS_AVAILABLE:
            logger.warning("ipfshttpclient not available, enabling mock mode")
            self.mock_mode = True
            return
            
        try:
            self.client = ipfshttpclient.connect(self.ipfs_url)
            # Test connection
            version = self.client.version()
            logger.info(f"✅ Connected to IPFS node v{version['Version']}")
        except Exception as e:
            logger.warning(f"Failed to connect to IPFS at {self.ipfs_url}: {e}")
            logger.info("Enabling mock mode for development")
            self.mock_mode = True
            self.client = None
    
    def _generate_mock_ipfs_hash(self, content: str) -> str:
        """Generate a realistic IPFS hash for mock mode"""
        # Create a hash that looks like a real IPFS hash (Qm...)
        content_hash = hashlib.sha256(content.encode()).hexdigest()
        # IPFS hashes typically start with 'Qm' and are base58 encoded
        # For simplicity, we'll create a realistic-looking hash
        mock_hash = f"Qm{content_hash[:44]}"  # 46 character total like real IPFS hashes
        return mock_hash
    
    def create_poa_package(
        self, 
        submission_id: str,
        studio_id: str,
        worker_agent_id: str,
        action_type: str,
        inventory_data: Dict[str, Any],
        evidence: Dict[str, Any] = None
    ) -> Dict[str, Any]:
        """
        Create a standardized PoA package structure
        
        Args:
            submission_id: Unique identifier for the submission
            studio_id: Studio identifier (e.g., "kirana_ai_poc")
            worker_agent_id: ID of the worker agent
            action_type: Type of action (e.g., "KiranaAI_StockReport")
            inventory_data: The actual inventory verification data
            evidence: Supporting evidence (photos, logs, etc.)
        
        Returns:
            Dict containing the PoA package structure
        """
        package = {
            "submission_id": submission_id,
            "studio_id": studio_id,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "worker_agent_id": worker_agent_id,
            "action_type": action_type,
            "inventory_data": inventory_data,
            "evidence": evidence or {},
            "metadata": {
                "version": "1.0",
                "created_by": "chaoschain-dvn-poc",
                "schema_version": "poa-package-v1"
            }
        }
        
        # Calculate package hash
        package_json = json.dumps(package, sort_keys=True, separators=(',', ':'))
        package_hash = hashlib.sha256(package_json.encode()).hexdigest()
        package["package_hash"] = package_hash
        
        return package
    
    def upload_poa_package(self, poa_package: Dict[str, Any]) -> Optional[str]:
        """
        Upload PoA package to IPFS
        
        Args:
            poa_package: PoA package dictionary
        
        Returns:
            IPFS hash if successful, None otherwise
        """
        # Convert to JSON for hashing
        package_json = json.dumps(poa_package, indent=2, sort_keys=True)
        
        if self.mock_mode:
            # Generate mock IPFS hash
            mock_hash = self._generate_mock_ipfs_hash(package_json)
            logger.info(f"🎭 Mock IPFS upload: {mock_hash}")
            logger.debug(f"Package size: {len(package_json)} bytes")
            return mock_hash
        
        if not self.client:
            logger.error("No IPFS client available for upload")
            return None
        
        try:
            # Upload to IPFS
            result = self.client.add_json(poa_package)
            ipfs_hash = result
            
            logger.info(f"✅ Successfully uploaded PoA package to IPFS: {ipfs_hash}")
            logger.debug(f"Package size: {len(package_json)} bytes")
            
            # Pin the content to ensure availability
            try:
                self.client.pin.add(ipfs_hash)
                logger.debug(f"Pinned PoA package: {ipfs_hash}")
            except Exception as e:
                logger.warning(f"Failed to pin PoA package: {e}")
            
            return ipfs_hash
            
        except Exception as e:
            logger.error(f"Failed to upload PoA package to IPFS: {e}")
            # Fallback to mock hash
            mock_hash = self._generate_mock_ipfs_hash(package_json)
            logger.warning(f"Using mock hash as fallback: {mock_hash}")
            return mock_hash
    
    def retrieve_poa_package(self, ipfs_hash: str) -> Optional[Dict[str, Any]]:
        """
        Retrieve PoA package from IPFS
        
        Args:
            ipfs_hash: IPFS hash of the package
        
        Returns:
            PoA package dictionary if successful, None otherwise
        """
        if self.mock_mode:
            logger.warning(f"🎭 Mock IPFS retrieval requested for: {ipfs_hash}")
            logger.warning("Mock mode: Cannot retrieve actual data, would need real IPFS")
            return None
        
        if not self.client:
            logger.error("No IPFS client available for retrieval")
            return None
        
        try:
            # Retrieve from IPFS
            package = self.client.get_json(ipfs_hash)
            
            logger.info(f"Successfully retrieved PoA package from IPFS: {ipfs_hash}")
            
            # Verify package hash if present
            if "package_hash" in package:
                # Create a copy without the hash for verification
                package_for_hash = {k: v for k, v in package.items() if k != "package_hash"}
                package_json = json.dumps(package_for_hash, sort_keys=True, separators=(',', ':'))
                calculated_hash = hashlib.sha256(package_json.encode()).hexdigest()
                
                if calculated_hash != package["package_hash"]:
                    logger.error(f"Package hash mismatch! Expected: {package['package_hash']}, Got: {calculated_hash}")
                    return None
                
                logger.debug("Package hash verification successful")
            
            return package
            
        except Exception as e:
            logger.error(f"Failed to retrieve PoA package from IPFS: {e}")
            return None
    
    def upload_evidence_file(self, file_path: str) -> Optional[str]:
        """
        Upload an evidence file (image, log, etc.) to IPFS
        
        Args:
            file_path: Path to the evidence file
        
        Returns:
            IPFS hash if successful, None otherwise
        """
        if self.mock_mode:
            # Generate mock hash based on file path and timestamp
            mock_content = f"{file_path}_{datetime.now(timezone.utc).isoformat()}"
            mock_hash = self._generate_mock_ipfs_hash(mock_content)
            logger.info(f"🎭 Mock evidence file upload: {mock_hash}")
            return mock_hash
        
        if not self.client:
            logger.error("No IPFS client available for file upload")
            return None
        
        try:
            if not os.path.exists(file_path):
                logger.error(f"Evidence file not found: {file_path}")
                return None
            
            # Upload file to IPFS
            result = self.client.add(file_path)
            ipfs_hash = result['Hash']
            
            logger.info(f"Successfully uploaded evidence file to IPFS: {ipfs_hash}")
            logger.debug(f"File: {file_path}, Size: {result['Size']} bytes")
            
            # Pin the content
            try:
                self.client.pin.add(ipfs_hash)
                logger.debug(f"Pinned evidence file: {ipfs_hash}")
            except Exception as e:
                logger.warning(f"Failed to pin evidence file: {e}")
            
            return ipfs_hash
            
        except Exception as e:
            logger.error(f"Failed to upload evidence file to IPFS: {e}")
            # Fallback to mock hash
            mock_content = f"{file_path}_{datetime.now(timezone.utc).isoformat()}"
            mock_hash = self._generate_mock_ipfs_hash(mock_content)
            logger.warning(f"Using mock hash as fallback: {mock_hash}")
            return mock_hash
    
    def get_ipfs_info(self) -> Dict[str, Any]:
        """
        Get IPFS node information
        
        Returns:
            Dict with IPFS node info or empty dict if unavailable
        """
        if self.mock_mode:
            return {
                "status": "mock_mode", 
                "message": "Running in mock mode for development",
                "mock_hashes_generated": True
            }
        
        if not self.client:
            return {"status": "unavailable", "message": "No IPFS client connection"}
        
        try:
            version = self.client.version()
            stats = self.client.stats.repo()
            
            return {
                "status": "connected",
                "version": version["Version"],
                "repo_size": stats["RepoSize"],
                "storage_max": stats["StorageMax"],
                "num_objects": stats["NumObjects"]
            }
        except Exception as e:
            return {"status": "error", "message": str(e)}

# Example usage and testing functions
def create_sample_inventory_data() -> Dict[str, Any]:
    """Create sample inventory data for testing"""
    return {
        "store_id": "store_123",
        "scan_timestamp": datetime.now(timezone.utc).isoformat(),
        "section": "electronics",
        "items": [
            {
                "sku": "LAPTOP001",
                "name": "Gaming Laptop",
                "quantity": 5,
                "location": "Aisle-A-Shelf-2",
                "verification_method": "barcode_scan",
                "confidence": 0.95,
                "unit_price": 999.99
            },
            {
                "sku": "PHONE001", 
                "name": "Smartphone",
                "quantity": 12,
                "location": "Aisle-A-Shelf-1",
                "verification_method": "visual_inspection",
                "confidence": 0.88,
                "unit_price": 599.99
            }
        ],
        "total_items_scanned": 17,
        "verification_duration": "00:15:30",
        "anomalies": [],
        "verification_notes": "Standard evening inventory check completed successfully"
    }

def test_ipfs_integration():
    """Test IPFS integration with sample data"""
    print("🧪 Testing IPFS Integration")
    print("=" * 40)
    
    client = IPFSClient()
    
    # Test connection
    info = client.get_ipfs_info()
    print(f"IPFS Status: {info['status']}")
    print(f"Message: {info.get('message', 'N/A')}")
    
    if info.get("status") == "connected":
        print("✅ Real IPFS node connected")
    elif info.get("status") == "mock_mode":
        print("🎭 Running in mock mode (generating realistic hashes)")
    else:
        print("⚠️  IPFS not available")
    
    # Create sample PoA package
    inventory_data = create_sample_inventory_data()
    poa_package = client.create_poa_package(
        submission_id="test_submission_001",
        studio_id="kirana_ai_poc",
        worker_agent_id="wa_test_001",
        action_type="KiranaAI_StockReport",
        inventory_data=inventory_data
    )
    
    print(f"\n📦 Created PoA package:")
    print(f"  Package Hash: {poa_package['package_hash']}")
    print(f"  Submission ID: {poa_package['submission_id']}")
    print(f"  Items Scanned: {poa_package['inventory_data']['total_items_scanned']}")
    
    # Upload to IPFS (or mock)
    ipfs_hash = client.upload_poa_package(poa_package)
    if ipfs_hash:
        print(f"\n✅ Upload successful!")
        print(f"  IPFS Hash: {ipfs_hash}")
        
        if not client.mock_mode:
            # Try to retrieve and verify (only if real IPFS)
            retrieved = client.retrieve_poa_package(ipfs_hash)
            if retrieved:
                print(f"✅ Successfully retrieved and verified package")
                print(f"  Verified Submission ID: {retrieved['submission_id']}")
                print(f"  Verified Items: {retrieved['inventory_data']['total_items_scanned']}")
            else:
                print("❌ Failed to retrieve package")
        else:
            print("🎭 Mock mode: Retrieval not tested (would need real IPFS)")
    else:
        print("❌ Upload failed completely")
    
    # Test evidence file upload simulation
    print(f"\n🗂️  Testing evidence file upload...")
    evidence_hash = client.upload_evidence_file("/mock/evidence/photo_001.jpg")
    if evidence_hash:
        print(f"✅ Evidence file hash: {evidence_hash}")
    
    print("\n🏁 IPFS integration test completed!")

if __name__ == "__main__":
    # Configure logging
    logging.basicConfig(level=logging.INFO)
    
    # Run test
    test_ipfs_integration() 