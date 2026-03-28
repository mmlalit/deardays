#!/bin/bash
# Usage: ./scripts/build.sh [dev|staging|prod] [apk|appbundle|ios|web|windows]
# Example: ./scripts/build.sh prod apk
# Example: ./scripts/build.sh staging appbundle

set -euo pipefail

ENV=${1:-prod}
TARGET=${2:-apk}
shift 2 || true

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

echo "Building $TARGET with $ENV environment..."
flutter build $TARGET $DART_DEFINES "$@"
