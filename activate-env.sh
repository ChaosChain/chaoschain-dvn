#!/bin/bash
# ChaosChain DVN PoC - Environment Activation Script

echo "🚀 Activating ChaosChain DVN PoC environment..."

# Activate virtual environment
source venv/bin/activate

# Set Python path
export PYTHONPATH="${PYTHONPATH}:$(pwd)"

# Check if .env file exists
if [ -f ".env" ]; then
    echo "✅ Loading environment variables from .env"
    set -a
    source .env
    set +a
else
    echo "⚠️  No .env file found. Copy config/environment.example to .env and configure your keys."
fi

echo "📦 Virtual environment activated: $(which python)"
echo "🔧 Python path: $PYTHONPATH"
echo ""
echo "Available commands:"
echo "  python agents/shared/constants.py      # Test configuration"
echo "  python agents/shared/ipfs_client.py    # Test IPFS client"
echo "  python -m pytest tests/               # Run tests"
echo ""
echo "Ready for development! 🎯" 