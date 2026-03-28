#!/bin/bash
# Usage: ./scripts/run.sh [dev|staging|prod] [additional flutter args]
# Example: ./scripts/run.sh dev -d chrome
# Example: ./scripts/run.sh prod --release

set -euo pipefail

ENV=${1:-dev}
shift || true

ENV_FILE=".env.${ENV}"
if [ ! -f "$ENV_FILE" ]; then
  echo "Error: $ENV_FILE not found"
  echo "Available environments:"
  ls -1 .env.* 2>/dev/null | sed 's/\.env\./  /' || echo "  (none)"
  exit 1
fi

DART_DEFINES=""
while IFS='=' read -r key value; do
  # Skip comments and empty lines
  [[ "$key" =~ ^#.*$ ]] && continue
  [[ -z "$key" ]] && continue
  # Trim whitespace
  key=$(echo "$key" | xargs)
  value=$(echo "$value" | xargs)
  [[ -z "$key" ]] && continue
  DART_DEFINES="$DART_DEFINES --dart-define=$key=$value"
done < "$ENV_FILE"

echo "Running with $ENV environment..."
flutter run $DART_DEFINES "$@"
