#!/bin/bash
# Start the DeployNOPE Dashboard
# Usage: ./dashboard/start.sh [port]
# Default port: 9876

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PORT="${1:-9876}"

echo "Starting DeployNOPE Dashboard on http://localhost:$PORT"
node "$SCRIPT_DIR/server.js" "$PORT"
