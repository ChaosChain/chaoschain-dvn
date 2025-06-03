"""
Inventory Verification Utility for Worker Agent
Provides realistic inventory scanning simulation with various scenarios
"""

import os
import sys
import random
import logging
from datetime import datetime, timezone
from typing import Dict, Any, List, Optional, Tuple

# Add project root to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(__file__))))

from agents.shared.constants import SAMPLE_INVENTORY_ITEMS, SAMPLE_STORES, WORKER_AGENT_DEFAULTS

logger = logging.getLogger(__name__)

class InventoryVerifier:
    """Simulates realistic inventory verification scenarios"""
    
    # Different verification scenarios
    SCENARIOS = {
        "normal": {
            "description": "Normal inventory levels with minor variations",
            "stock_variation": (-0.1, 0.1),  # ±10%
            "confidence_range": (0.85, 0.98),
            "anomaly_probability": 0.05
        },
        "low_stock": {
            "description": "Low stock situation with potential out-of-stock items",
            "stock_variation": (-0.5, 0.0),  # -50% to 0%
            "confidence_range": (0.80, 0.95),
            "anomaly_probability": 0.3
        },
        "restock": {
            "description": "Recent restocking with higher than normal inventory",
            "stock_variation": (0.0, 0.4),  # 0% to +40%
            "confidence_range": (0.90, 0.99),
            "anomaly_probability": 0.02
        },
        "problematic": {
            "description": "Problematic scan with low confidence and anomalies",
            "stock_variation": (-0.3, 0.3),  # ±30%
            "confidence_range": (0.60, 0.85),
            "anomaly_probability": 0.4
        },
        "mixed": {
            "description": "Mixed scenario with both high and low stock items",
            "stock_variation": (-0.4, 0.3),  # -40% to +30%
            "confidence_range": (0.75, 0.95),
            "anomaly_probability": 0.15
        }
    }
    
    def __init__(self):
        """Initialize the inventory verifier"""
        self.verification_methods = WORKER_AGENT_DEFAULTS["verification_methods"]
        self.confidence_threshold = WORKER_AGENT_DEFAULTS["confidence_threshold"]
    
    def scan_inventory(self, 
                      store_id: str, 
                      section: str, 
                      scenario: str = "normal",
                      custom_items: List[Dict[str, Any]] = None) -> Tuple[List[Dict[str, Any]], Dict[str, Any]]:
        """
        Simulate inventory scanning for a store section
        
        Args:
            store_id: Store identifier
            section: Store section to scan
            scenario: Verification scenario (normal, low_stock, restock, etc.)
            custom_items: Custom item list to use instead of defaults
            
        Returns:
            Tuple of (scanned_items, scan_metadata)
        """
        logger.info(f"🔍 Starting {scenario} inventory scan for {store_id}/{section}")
        
        # Get scenario parameters
        if scenario not in self.SCENARIOS:
            logger.warning(f"Unknown scenario '{scenario}', using 'normal'")
            scenario = "normal"
            
        scenario_config = self.SCENARIOS[scenario]
        
        # Get items to scan
        items_to_scan = custom_items or self._get_items_for_section(section)
        
        if not items_to_scan:
            logger.warning(f"No items found for section '{section}', using all sample items")
            items_to_scan = SAMPLE_INVENTORY_ITEMS
        
        # Simulate scanning each item
        scanned_items = []
        anomaly_count = 0
        total_confidence = 0
        
        for item_template in items_to_scan:
            scanned_item = self._scan_single_item(item_template, scenario_config, store_id)
            scanned_items.append(scanned_item)
            
            total_confidence += scanned_item["confidence"]
            
            # Count anomalies
            if scanned_item["quantity"] == 0 or scanned_item["confidence"] < self.confidence_threshold:
                anomaly_count += 1
        
        # Calculate overall metrics
        avg_confidence = total_confidence / len(scanned_items) if scanned_items else 0
        
        # Generate scan metadata
        scan_metadata = {
            "scenario": scenario,
            "scenario_description": scenario_config["description"],
            "total_items_scanned": len(scanned_items),
            "average_confidence": avg_confidence,
            "anomaly_count": anomaly_count,
            "scan_duration": self._generate_scan_duration(len(scanned_items)),
            "scan_timestamp": datetime.now(timezone.utc).isoformat(),
            "verification_quality": self._assess_verification_quality(avg_confidence, anomaly_count, len(scanned_items))
        }
        
        logger.info(f"✅ Scan completed: {len(scanned_items)} items, avg confidence: {avg_confidence:.2f}, anomalies: {anomaly_count}")
        
        return scanned_items, scan_metadata
    
    def _get_items_for_section(self, section: str) -> List[Dict[str, Any]]:
        """Get items that match the specified section"""
        matching_items = []
        
        for item in SAMPLE_INVENTORY_ITEMS:
            # Check if section matches item category or is in the category
            if (section.lower() in item["category"].lower() or 
                item["category"].lower() in section.lower()):
                matching_items.append(item)
        
        return matching_items
    
    def _scan_single_item(self, 
                         item_template: Dict[str, Any], 
                         scenario_config: Dict[str, Any],
                         store_id: str) -> Dict[str, Any]:
        """Simulate scanning a single inventory item"""
        
        # Calculate quantity with scenario-based variation
        base_qty = item_template["typical_quantity"]
        stock_min, stock_max = scenario_config["stock_variation"]
        variation = random.uniform(stock_min, stock_max)
        actual_qty = max(0, int(base_qty * (1 + variation)))
        
        # Generate confidence based on scenario
        conf_min, conf_max = scenario_config["confidence_range"]
        confidence = random.uniform(conf_min, conf_max)
        
        # Occasionally introduce anomalies based on scenario
        if random.random() < scenario_config["anomaly_probability"]:
            if random.random() < 0.5:
                # Force out of stock
                actual_qty = 0
            else:
                # Force low confidence
                confidence = random.uniform(0.5, self.confidence_threshold - 0.01)
        
        # Select verification method
        verification_method = random.choice(self.verification_methods)
        
        # Generate location
        location = f"Aisle-{random.choice(['A', 'B', 'C', 'D'])}-Shelf-{random.randint(1, 6)}"
        
        scanned_item = {
            "sku": item_template["sku"],
            "name": item_template["name"],
            "category": item_template["category"],
            "quantity": actual_qty,
            "expected_quantity": base_qty,
            "quantity_variance": actual_qty - base_qty,
            "unit_price": item_template["unit_price"],
            "total_value": actual_qty * item_template["unit_price"],
            "location": location,
            "verification_method": verification_method,
            "confidence": confidence,
            "scan_timestamp": datetime.now(timezone.utc).isoformat(),
            "store_id": store_id,
            "barcode_readable": confidence > 0.8,
            "requires_manual_check": confidence < self.confidence_threshold or actual_qty == 0
        }
        
        return scanned_item
    
    def _generate_scan_duration(self, item_count: int) -> str:
        """Generate realistic scan duration based on item count"""
        # Base time: 30 seconds + 45-90 seconds per item
        base_seconds = 30
        per_item_seconds = random.randint(45, 90)
        total_seconds = base_seconds + (item_count * per_item_seconds)
        
        # Add some random variation (±20%)
        variation = random.uniform(0.8, 1.2)
        total_seconds = int(total_seconds * variation)
        
        # Convert to HH:MM:SS format
        hours = total_seconds // 3600
        minutes = (total_seconds % 3600) // 60
        seconds = total_seconds % 60
        
        return f"{hours:02d}:{minutes:02d}:{seconds:02d}"
    
    def _assess_verification_quality(self, 
                                   avg_confidence: float, 
                                   anomaly_count: int, 
                                   total_items: int) -> str:
        """Assess the overall quality of the verification"""
        
        anomaly_ratio = anomaly_count / total_items if total_items > 0 else 0
        
        if avg_confidence >= 0.95 and anomaly_ratio <= 0.05:
            return "excellent"
        elif avg_confidence >= 0.85 and anomaly_ratio <= 0.15:
            return "good"
        elif avg_confidence >= 0.75 and anomaly_ratio <= 0.25:
            return "acceptable"
        elif avg_confidence >= 0.65 and anomaly_ratio <= 0.40:
            return "poor"
        else:
            return "failed"
    
    def detect_anomalies(self, scanned_items: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """Detect and categorize anomalies in scanned items"""
        anomalies = []
        
        for item in scanned_items:
            # Out of stock anomaly
            if item["quantity"] == 0:
                anomalies.append({
                    "type": "out_of_stock",
                    "sku": item["sku"],
                    "item_name": item["name"],
                    "description": f"Item {item['name']} is out of stock",
                    "severity": "high",
                    "expected_quantity": item["expected_quantity"],
                    "actual_quantity": 0,
                    "location": item["location"]
                })
            
            # Low stock anomaly (less than 20% of expected)
            elif item["quantity"] < item["expected_quantity"] * 0.2:
                anomalies.append({
                    "type": "low_stock",
                    "sku": item["sku"],
                    "item_name": item["name"],
                    "description": f"Low stock: {item['quantity']} (expected ~{item['expected_quantity']})",
                    "severity": "medium",
                    "expected_quantity": item["expected_quantity"],
                    "actual_quantity": item["quantity"],
                    "location": item["location"]
                })
            
            # Overstock anomaly (more than 150% of expected)
            elif item["quantity"] > item["expected_quantity"] * 1.5:
                anomalies.append({
                    "type": "overstock",
                    "sku": item["sku"],
                    "item_name": item["name"],
                    "description": f"Overstock: {item['quantity']} (expected ~{item['expected_quantity']})",
                    "severity": "low",
                    "expected_quantity": item["expected_quantity"],
                    "actual_quantity": item["quantity"],
                    "location": item["location"]
                })
            
            # Low confidence anomaly
            if item["confidence"] < self.confidence_threshold:
                anomalies.append({
                    "type": "low_confidence",
                    "sku": item["sku"],
                    "item_name": item["name"],
                    "description": f"Low scan confidence: {item['confidence']:.2f}",
                    "severity": "medium",
                    "confidence": item["confidence"],
                    "verification_method": item["verification_method"],
                    "location": item["location"]
                })
            
            # Manual check required
            if item["requires_manual_check"]:
                anomalies.append({
                    "type": "manual_check_required",
                    "sku": item["sku"],
                    "item_name": item["name"],
                    "description": f"Item requires manual verification",
                    "severity": "medium",
                    "reason": "Low confidence or out of stock",
                    "location": item["location"]
                })
        
        return anomalies
    
    def generate_verification_report(self, 
                                   scanned_items: List[Dict[str, Any]], 
                                   scan_metadata: Dict[str, Any],
                                   store_id: str,
                                   section: str) -> Dict[str, Any]:
        """Generate a comprehensive verification report"""
        
        anomalies = self.detect_anomalies(scanned_items)
        
        # Calculate financial metrics
        total_value = sum(item["total_value"] for item in scanned_items)
        items_requiring_attention = len([item for item in scanned_items if item["requires_manual_check"]])
        
        # Categorize items by status
        in_stock_items = [item for item in scanned_items if item["quantity"] > 0]
        out_of_stock_items = [item for item in scanned_items if item["quantity"] == 0]
        low_stock_items = [item for item in scanned_items if 0 < item["quantity"] < item["expected_quantity"] * 0.2]
        
        report = {
            "report_id": f"{store_id}_{section}_{int(datetime.now().timestamp())}",
            "store_id": store_id,
            "section": section,
            "scan_metadata": scan_metadata,
            "summary": {
                "total_items_scanned": len(scanned_items),
                "total_inventory_value": total_value,
                "average_confidence": scan_metadata["average_confidence"],
                "verification_quality": scan_metadata["verification_quality"],
                "items_requiring_attention": items_requiring_attention
            },
            "stock_status": {
                "in_stock": len(in_stock_items),
                "out_of_stock": len(out_of_stock_items),
                "low_stock": len(low_stock_items),
                "adequately_stocked": len(in_stock_items) - len(low_stock_items)
            },
            "anomalies": {
                "total_count": len(anomalies),
                "by_severity": {
                    "high": len([a for a in anomalies if a["severity"] == "high"]),
                    "medium": len([a for a in anomalies if a["severity"] == "medium"]),
                    "low": len([a for a in anomalies if a["severity"] == "low"])
                },
                "details": anomalies
            },
            "items": scanned_items,
            "generated_at": datetime.now(timezone.utc).isoformat()
        }
        
        return report

def demo_verification_scenarios():
    """Demonstrate different verification scenarios"""
    verifier = InventoryVerifier()
    
    print("📊 Inventory Verification Scenario Demo")
    print("=" * 60)
    
    demo_scenarios = [
        ("store_123", "electronics", "normal"),
        ("store_456", "smartphones", "low_stock"),
        ("store_123", "accessories", "restock"),
        ("store_456", "tablets", "problematic"),
        ("store_123", "gaming", "mixed")
    ]
    
    for store_id, section, scenario in demo_scenarios:
        print(f"\n🔍 {scenario.upper()} scenario: {store_id}/{section}")
        print("-" * 40)
        
        scanned_items, metadata = verifier.scan_inventory(store_id, section, scenario)
        anomalies = verifier.detect_anomalies(scanned_items)
        
        print(f"Items scanned: {metadata['total_items_scanned']}")
        print(f"Average confidence: {metadata['average_confidence']:.2f}")
        print(f"Quality: {metadata['verification_quality']}")
        print(f"Anomalies: {len(anomalies)}")
        print(f"Duration: {metadata['scan_duration']}")
        
        if anomalies:
            print("📋 Anomalies found:")
            for anomaly in anomalies[:3]:  # Show first 3
                print(f"  - {anomaly['type']}: {anomaly['description']}")
            if len(anomalies) > 3:
                print(f"  ... and {len(anomalies) - 3} more")

if __name__ == "__main__":
    demo_verification_scenarios() 