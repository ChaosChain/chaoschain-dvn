"""
ChaosChain DVN PoC - Complete End-to-End Demo
Demonstrates the full DVN workflow with Worker and Verifier Agents
"""

import os
import sys
import time
import json
from datetime import datetime, timezone
from typing import List, Dict, Any
import importlib.util

# Add project root to path
sys.path.append(os.path.dirname(os.path.dirname(__file__)))

# Import agents - need to handle hyphenated directory names
import importlib.util
import os

# Load Worker Agent
worker_agent_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "agents", "worker-agent", "worker_agent.py")
spec = importlib.util.spec_from_file_location("worker_agent", worker_agent_path)
worker_agent_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(worker_agent_module)
WorkerAgent = worker_agent_module.WorkerAgent

# Load Verifier Agent
verifier_agent_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "agents", "verifier-agent", "verifier_agent.py")
spec = importlib.util.spec_from_file_location("verifier_agent", verifier_agent_path)
verifier_agent_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verifier_agent_module)
VerifierAgent = verifier_agent_module.VerifierAgent

from agents.shared.constants import *

def print_section(title: str, width: int = 80):
    """Print a formatted section header"""
    print("\n" + "=" * width)
    print(f" {title.center(width-2)} ")
    print("=" * width)

def print_subsection(title: str, width: int = 60):
    """Print a formatted subsection header"""
    print(f"\n{'-' * width}")
    print(f" {title}")
    print(f"{'-' * width}")

def run_full_dvn_demo():
    """Run the complete DVN demonstration"""
    
    print_section("🌟 ChaosChain DVN PoC - Complete End-to-End Demo")
    print("This demonstration showcases the full Decentralized Verification Network workflow:")
    print("1. Worker Agent performs inventory verification and submits PoA")
    print("2. Multiple Verifier Agents evaluate the submission")
    print("3. Consensus mechanism processes attestations")
    print("4. Final verification result is determined")
    
    # Demo configuration
    demo_config = {
        "store_scenarios": [
            {"store_id": "store_123", "section": "electronics", "action": "KiranaAI_StockReport"},
            {"store_id": "store_456", "section": "smartphones", "action": "KiranaAI_InventoryAudit"},
            {"store_id": "store_789", "section": "accessories", "action": "KiranaAI_ReorderAlert"}
        ],
        "verifier_agents": [
            {"specialization": "electronics", "count": 2},
            {"specialization": "inventory", "count": 2}, 
            {"specialization": "general", "count": 1}
        ]
    }
    
    print(f"\n📋 Demo Configuration:")
    print(f"   • {len(demo_config['store_scenarios'])} different store scenarios")
    print(f"   • {sum(va['count'] for va in demo_config['verifier_agents'])} verifier agents")
    print(f"   • Full simulation mode (no real blockchain transactions)")
    
    input("\nPress Enter to start the demo...")
    
    # Run demonstrations for each store scenario
    for i, scenario in enumerate(demo_config["store_scenarios"], 1):
        print_section(f"📦 Scenario {i}/{len(demo_config['store_scenarios'])}: {scenario['store_id']} - {scenario['section']}")
        
        # Phase 1: Worker Agent Submission
        print_subsection("🤖 Phase 1: Worker Agent Verification")
        print(f"Store: {scenario['store_id']}")
        print(f"Section: {scenario['section']}")
        print(f"Action: {scenario['action']}")
        
        # Initialize Worker Agent
        worker_agent = WorkerAgent(private_key="simulation")
        
        print(f"\n🔄 Executing inventory verification...")
        worker_result = worker_agent.execute_verification(
            store_id=scenario["store_id"],
            section=scenario["section"],
            action_type=scenario["action"]
        )
        
        if worker_result["status"] != "submitted":
            print(f"❌ Worker Agent failed: {worker_result.get('error_message', 'Unknown error')}")
            continue
        
        print(f"✅ Worker Agent completed successfully!")
        print(f"   • Items Scanned: {worker_result['total_items']}")
        print(f"   • Scan Confidence: {worker_result['scan_confidence']:.2f}")
        print(f"   • Anomalies: {len(worker_result['anomalies'])}")
        print(f"   • IPFS Hash: {worker_result['ipfs_hash']}")
        print(f"   • Transaction Hash: {worker_result['tx_hash']}")
        print(f"   • Submission ID: {worker_result['submission_id']}")
        
        # Generate unique submission ID for verifiers
        submission_id = f"{scenario['store_id']}_{scenario['action']}_{worker_result['submission_id']}"
        
        time.sleep(1)  # Brief pause for dramatic effect
        
        # Phase 2: Verifier Agent Evaluations
        print_subsection("🔍 Phase 2: Verifier Agent Evaluations")
        
        verifier_results = []
        attestation_count = 0
        
        for va_config in demo_config["verifier_agents"]:
            specialization = va_config["specialization"]
            count = va_config["count"]
            
            print(f"\n📊 {specialization.upper()} Verifier Agents ({count} agents):")
            
            for j in range(count):
                agent_id = f"va_{specialization}_{j+1:03d}"
                
                # Initialize Verifier Agent
                verifier_agent = VerifierAgent(
                    private_key="simulation",
                    agent_id=agent_id,
                    specialization=specialization
                )
                
                print(f"   🔍 {agent_id} evaluating submission...")
                
                # Evaluate submission
                eval_result = verifier_agent.evaluate_submission(submission_id)
                verifier_results.append(eval_result)
                
                if eval_result["status"] == "completed":
                    decision = "APPROVE" if eval_result["attestation_decision"] else "REJECT"
                    score = eval_result["overall_score"]
                    confidence = eval_result["evaluation_confidence"]
                    
                    print(f"   ✅ {agent_id}: {decision} (score: {score:.2f}, confidence: {confidence:.2f})")
                    
                    if eval_result["attestation_decision"]:
                        attestation_count += 1
                else:
                    print(f"   ❌ {agent_id}: FAILED - {eval_result.get('error_message', 'Unknown error')}")
        
        time.sleep(1)
        
        # Phase 3: Consensus Analysis
        print_subsection("🎯 Phase 3: Consensus Analysis")
        
        total_verifiers = len(verifier_results)
        successful_evaluations = len([r for r in verifier_results if r["status"] == "completed"])
        approval_count = attestation_count
        rejection_count = successful_evaluations - approval_count
        
        if successful_evaluations == 0:
            consensus_result = "FAILED - No successful evaluations"
        else:
            approval_rate = approval_count / successful_evaluations
            consensus_threshold = CONSENSUS_CONFIG["consensus_threshold_percent"] / 100
            
            if approval_rate >= consensus_threshold:
                consensus_result = "VERIFIED ✅"
            else:
                consensus_result = "REJECTED ❌"
        
        print(f"📈 Consensus Summary:")
        print(f"   • Total Verifiers: {total_verifiers}")
        print(f"   • Successful Evaluations: {successful_evaluations}")
        print(f"   • Approvals: {approval_count}")
        print(f"   • Rejections: {rejection_count}")
        print(f"   • Approval Rate: {approval_count/successful_evaluations*100:.1f}%" if successful_evaluations > 0 else "   • Approval Rate: N/A")
        print(f"   • Consensus Threshold: {CONSENSUS_CONFIG['consensus_threshold_percent']}%")
        print(f"   • Final Result: {consensus_result}")
        
        # Phase 4: Detailed Results
        print_subsection("📋 Phase 4: Detailed Analysis")
        
        if successful_evaluations > 0:
            # Calculate average scores by specialization
            specialization_stats = {}
            for result in verifier_results:
                if result["status"] == "completed":
                    spec = result["attestation_evidence"]["specialization"]
                    if spec not in specialization_stats:
                        specialization_stats[spec] = {"scores": [], "decisions": []}
                    
                    specialization_stats[spec]["scores"].append(result["overall_score"])
                    specialization_stats[spec]["decisions"].append(result["attestation_decision"])
            
            print("🏷️  Results by Specialization:")
            for spec, stats in specialization_stats.items():
                avg_score = sum(stats["scores"]) / len(stats["scores"])
                approval_rate = sum(stats["decisions"]) / len(stats["decisions"]) * 100
                print(f"   • {spec.upper()}: Avg Score {avg_score:.2f}, Approval Rate {approval_rate:.0f}%")
            
            # Show evaluation notes
            all_notes = []
            for result in verifier_results:
                if result["status"] == "completed" and result.get("attestation_evidence", {}).get("evaluation_notes"):
                    all_notes.extend(result["attestation_evidence"]["evaluation_notes"])
            
            if all_notes:
                print(f"\n📝 Evaluation Notes:")
                unique_notes = list(set(all_notes))
                for note in unique_notes[:3]:  # Show top 3 unique notes
                    print(f"   • {note}")
        
        print(f"\n⏱️  Scenario {i} completed in simulated real-time")
        
        if i < len(demo_config["store_scenarios"]):
            input("\nPress Enter to continue to next scenario...")
    
    # Final Summary
    print_section("🎉 Demo Complete - DVN Workflow Summary")
    
    print("✅ Successfully demonstrated:")
    print("   • Worker Agent inventory verification and PoA submission")
    print("   • Multiple Verifier Agent evaluation workflows")
    print("   • Specialized agent evaluation criteria (electronics, inventory, general)")
    print("   • IPFS integration with mock mode fallback")
    print("   • Consensus mechanism simulation")
    print("   • End-to-end LangGraph workflow execution")
    
    print("\n🔧 Technical Components Verified:")
    print("   • LangGraph StateGraph workflows")
    print("   • IPFS mock client with realistic hash generation")
    print("   • Web3 simulation mode for blockchain operations")
    print("   • Specialized evaluation algorithms")
    print("   • Cryptographic attestation simulation")
    print("   • Multi-agent consensus processing")
    
    print("\n🚀 Ready for Next Phase:")
    print("   • Real IPFS node integration")
    print("   • Live blockchain transactions")
    print("   • Advanced consensus algorithms")
    print("   • Performance optimization")
    print("   • Monitoring and analytics dashboard")
    
    print("\n" + "=" * 80)
    print(" Thank you for exploring the ChaosChain DVN PoC! ".center(78))
    print("=" * 80)

def run_quick_demo():
    """Run a quick simplified demo for testing"""
    print("🚀 Quick DVN Demo")
    print("=" * 50)
    
    # Single scenario demo
    print("\n🤖 Worker Agent: Scanning store_123/electronics...")
    worker = WorkerAgent(private_key="simulation")
    worker_result = worker.execute_verification("store_123", "electronics")
    
    if worker_result["status"] == "submitted":
        print(f"✅ Worker completed: {worker_result['total_items']} items, confidence {worker_result['scan_confidence']:.2f}")
        
        submission_id = f"quick_demo_{worker_result['submission_id']}"
        
        print(f"\n🔍 Verifier Agents evaluating {submission_id}...")
        
        # Test 3 different verifier agents
        specializations = ["electronics", "inventory", "general"]
        decisions = []
        
        for spec in specializations:
            verifier = VerifierAgent(private_key="simulation", specialization=spec)
            result = verifier.evaluate_submission(submission_id)
            
            if result["status"] == "completed":
                decision = "APPROVE" if result["attestation_decision"] else "REJECT"
                print(f"   {spec}: {decision} (score: {result['overall_score']:.2f})")
                decisions.append(result["attestation_decision"])
            else:
                print(f"   {spec}: FAILED")
        
        # Simple consensus
        if len(decisions) > 0:
            approval_rate = sum(decisions) / len(decisions)
            final_result = "VERIFIED" if approval_rate >= 0.67 else "REJECTED"
            print(f"\n🎯 Final Result: {final_result} ({approval_rate*100:.0f}% approval)")
        
    else:
        print(f"❌ Worker failed: {worker_result.get('error_message')}")
    
    print("\n✅ Quick demo complete!")

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="ChaosChain DVN Demo")
    parser.add_argument("--quick", action="store_true", help="Run quick demo instead of full demo")
    
    args = parser.parse_args()
    
    if args.quick:
        run_quick_demo()
    else:
        run_full_dvn_demo() 