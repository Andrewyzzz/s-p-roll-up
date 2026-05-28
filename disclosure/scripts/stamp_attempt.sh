#!/usr/bin/env bash
# stamp_attempt.sh — Per-attempt disclosure timestamping workflow
#
# Usage:
#   ./stamp_attempt.sh <vendor_slug> <channel> <content_file>
#
# Example:
#   ./stamp_attempt.sh "vendor-a" "twitter-dm" "/tmp/outreach.txt"
#
# What this does:
#   1. Creates disclosure/attempts/YYYY-MM-DD_<vendor>_<channel>/
#   2. Copies content file, computes SHA-256
#   3. Runs `ots stamp` on content file
#   4. Writes metadata.json
#   5. git add + git commit + git push (public timestamp anchor)
#   6. Updates disclosure_commitments.json
#
# Requirements: ots (opentimestamps-client), git, sha256sum / shasum

set -euo pipefail

VENDOR="${1:?Usage: $0 <vendor_slug> <channel> <content_file>}"
CHANNEL="${2:?Usage: $0 <vendor_slug> <channel> <content_file>}"
CONTENT_FILE="${3:?Usage: $0 <vendor_slug> <channel> <content_file>}"

# Resolve repo root (script lives in disclosure/scripts/)
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DATE="$(date -u +%Y-%m-%d)"
ATTEMPT_DIR="${REPO_ROOT}/disclosure/attempts/${DATE}_${VENDOR}_${CHANNEL}"
COMMITMENTS="${REPO_ROOT}/disclosure/disclosure_commitments.json"

echo "==> Creating attempt directory: ${ATTEMPT_DIR}"
mkdir -p "${ATTEMPT_DIR}"

# Copy content
cp "${CONTENT_FILE}" "${ATTEMPT_DIR}/content.txt"

# Compute SHA-256
if command -v sha256sum &>/dev/null; then
    SHA256=$(sha256sum "${ATTEMPT_DIR}/content.txt" | awk '{print $1}')
else
    SHA256=$(shasum -a 256 "${ATTEMPT_DIR}/content.txt" | awk '{print $1}')
fi
echo "==> SHA-256: ${SHA256}"

# OpenTimestamps stamp
echo "==> Stamping with OpenTimestamps..."
if command -v ots &>/dev/null; then
    ots stamp "${ATTEMPT_DIR}/content.txt"
    OTS_STATUS="stamped (pending Bitcoin confirmation)"
else
    echo "WARNING: ots not found. Skipping OTS stamp. Install with: pip install opentimestamps-client"
    OTS_STATUS="ots_not_installed"
fi

# Write metadata.json
cat > "${ATTEMPT_DIR}/metadata.json" <<EOF
{
  "vendor": "${VENDOR}",
  "channel": "${CHANNEL}",
  "date_utc": "${DATE}",
  "content_sha256": "${SHA256}",
  "ots_status": "${OTS_STATUS}",
  "git_commit_hash": "PENDING"
}
EOF

# Git commit
echo "==> Committing to git..."
cd "${REPO_ROOT}"
git add "disclosure/attempts/${DATE}_${VENDOR}_${CHANNEL}/"
COMMIT_MSG="disclosure: ${DATE} outreach to ${VENDOR} via ${CHANNEL}"
git commit -m "${COMMIT_MSG}"
GIT_HASH=$(git rev-parse HEAD)
echo "==> Git commit: ${GIT_HASH}"

# Update metadata with actual commit hash
if command -v python3 &>/dev/null; then
    python3 - <<PYEOF
import json, sys
with open("${ATTEMPT_DIR}/metadata.json") as f:
    m = json.load(f)
m["git_commit_hash"] = "${GIT_HASH}"
with open("${ATTEMPT_DIR}/metadata.json", "w") as f:
    json.dump(m, f, indent=2)
print("  metadata.json updated with git hash")
PYEOF
fi

# Update disclosure_commitments.json
if command -v python3 &>/dev/null; then
    python3 - <<PYEOF
import json, os
path = "${COMMITMENTS}"
with open(path) as f:
    data = json.load(f)
entry = {
    "vendor": "${VENDOR}",
    "date": "${DATE}",
    "channel": "${CHANNEL}",
    "git_commit_hash": "${GIT_HASH}",
    "opentimestamps_proof": "disclosure/attempts/${DATE}_${VENDOR}_${CHANNEL}/content.txt.ots",
    "content_sha256": "${SHA256}"
}
data["disclosure_attempts"].append(entry)
with open(path, "w") as f:
    json.dump(data, f, indent=2)
print("  disclosure_commitments.json updated")
PYEOF
    git add disclosure/disclosure_commitments.json
    git commit -m "disclosure: update commitments index for ${DATE}_${VENDOR}_${CHANNEL}"
    GIT_HASH2=$(git rev-parse HEAD)
fi

# Push to remote
echo "==> Pushing to remote..."
git push origin HEAD

echo ""
echo "==> Done. Attempt recorded:"
echo "    Directory:   disclosure/attempts/${DATE}_${VENDOR}_${CHANNEL}/"
echo "    SHA-256:     ${SHA256}"
echo "    Git commit:  ${GIT_HASH}"
echo "    OTS:         ${OTS_STATUS}"
echo ""
echo "    Verify OTS (after Bitcoin confirmation ~1 hour):"
echo "    ots verify disclosure/attempts/${DATE}_${VENDOR}_${CHANNEL}/content.txt.ots"
