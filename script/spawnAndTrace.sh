#!/usr/bin/env bash
set -e

if [ -z "$1" ]; then
  echo "Usage: ./scripts/spawnAndTrace.sh <calldata>"
  exit 1
fi

CALLDATA=$1
RPC_URL="https://rpc.hyperliquid.xyz/evm"
FORK_BLOCK=$(cast block-number --rpc-url $RPC_URL)

# ✅ Load environment vars (PRIVATE_KEY, etc.)
if [ -f ".env" ]; then
  source .env
else
  echo ".env file not found"
  exit 1
fi

if [ -z "$PRIVATE_KEY" ]; then
  echo "Missing PRIVATE_KEY in .env"
  exit 1
fi

echo "🚀 Forking Hyperliquid at block $FORK_BLOCK"

# ✅ Start fork in background
anvil --fork-url $RPC_URL \
  --fork-block-number $FORK_BLOCK \
  --chain-id 999 \
  --port 8545 \
  --silent &
ANVIL_PID=$!
sleep 3

# ✅ Run Forge script
forge script scripts/TraceExecutor.s.sol \
  --rpc-url http://127.0.0.1:8545 \
  --sig "run(bytes)" $CALLDATA \
  --broadcast \
  --trace \
  -vvvv

# ✅ Clean up fork
kill $ANVIL_PID
