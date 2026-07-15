#!/usr/bin/env bash
# DevFlow next ADR number (ADR-0023 extraction). Prints the next docs/decisions/ number:
# the highest `NNNN` prefix + 1, zero-padded to 4 digits (`0001` if none). Shared by
# record-decision and reconcile-contract so both compute it identically (highest+1, gap-tolerant).
set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}"
python3 - <<'PY'
import glob, os, re
nums = [int(m.group(1)) for f in glob.glob("docs/decisions/*.md")
        if (m := re.match(r"(\d{4})", os.path.basename(f)))]
print(f"{(max(nums) + 1) if nums else 1:04d}")
PY
