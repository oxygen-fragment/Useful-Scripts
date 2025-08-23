#!/usr/bin/env bash
set -euo pipefail

# init-pipeline.sh
# Creates a universal, repo-agnostic multi-agent SLICE workflow for Claude Code.

FORCE=0
WITH_VSCODE=0
DATE="$(date +%Y%m%d)"
TIME="$(date +%H%M)"
FEATURE_ID="F-${DATE}-001"

usage() {
  cat <<'HELP'
Usage: bash init-pipeline.sh [--force] [--with-vscode]

Creates the following files if missing:
  .pipeline/AGENTS.md
  .pipeline/MACROS.md
  .pipeline/CONTEXT.md
  .pipeline/ROADMAP.md
Optionally:
  .vscode/tasks.json (with --with-vscode)

Flags:
  --force         Overwrite existing files (otherwise we skip)
  --with-vscode   Add minimal VS Code tasks (streamlit/run & pytest)
HELP
}

for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    --with-vscode) WITH_VSCODE=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $arg"; usage; exit 1 ;;
  esac
done

# Helpers
ensure_dir() { mkdir -p "$1"; }
write_file() {
  local path="$1"
  local content="$2"
  if [[ -e "$path" && $FORCE -eq 0 ]]; then
    echo "• Skipped (exists): $path"
  else
    ensure_dir "$(dirname "$path")"
    printf "%s" "$content" > "$path"
    echo "✓ Wrote: $path"
  fi
}

# --------------------------
# Templates
# --------------------------

AGENTS_MD='
# Pipeline Agents (repo-agnostic)

## 1) Clarifier Agent (used by `/clarify`)
You are the **Clarifier Agent**.
Input: a rough human request.
Output: a precise **Feature Brief** + an APPEND block for ROADMAP.md.

Rules:
- Ask at most 2 crisp questions only if absolutely needed; otherwise make safe defaults.
- Extract: Title, Area (path or "repo-wide"), Constraints (verbatim), Definition of Done (observable).
- Generate a stable Feature ID: F-YYYYMMDD-###.
- Emit an APPEND block:

<!-- APPEND START ROADMAP.md -->
<!-- FEATURE-START id:<F-ID> title: <Title> -->
### Feature: <Title>
**ID:** <F-ID>
**Area:** <Area>
**Constraints:** <comma list or '\''none'\''>
**Definition of Done:** <one paragraph>

#### Slices
<!-- Clarifier does NOT generate slices -->
<!-- FEATURE-END -->
<!-- APPEND END ROADMAP.md -->

Stop after emitting the block and a one-line summary.

---

## 2) Planner Agent (used by `/plan`)
You are the **Planner Agent**.
Input: a Feature ID or Title. Read ROADMAP.md for that Feature.
Output: an ordered **Slice Plan** appended under that Feature.

Rules:
- Create 2–6 slices max; each ≤30 minutes; repo-agnostic wording.
- Generate Slice IDs: S-YYYYMMDD-<feature-seq>-<slice-seq>.
- Each slice: Goal, Scope (paths or '\''TBD'\''), Constraints (inherit + extras), Steps (2–4 tiny steps), Acceptance (2–3 observable checks), Status: ☐ Pending.
- Only append; do not modify prior text except adding/updating the feature’s "#### Slices" list.

Emit:

<!-- APPEND START ROADMAP.md -->
(update the matching Feature block by inserting/updating its “#### Slices” list with the new slice entries; keep prior slices intact)
<!-- APPEND END ROADMAP.md -->

Stop after emitting the block and a bullet list of the slice IDs.

---

## 3) Slicer Agent (used by `/slice`)
You are the **Slicer Agent**.
Input: a Slice ID (or ordinal) that exists in ROADMAP.md.
Output: a concrete, tiny plan for JUST that slice and, if appropriate, a minimal unified diff + run commands.

Rules:
- Respect the slice'\''s Constraints and Scope.
- If uncertain about interfaces, propose a **lowest-cost experiment** (MRE or a 5–10 line test) instead of touching code.
- Keep code diffs ≤ ~30 lines and at most one new file.
- Always produce:
  1) SLICE-PLAN (S/L/I/C/E)
  2) Either a minimal diff OR an MRE snippet to create
  3) A patch to ROADMAP.md updating ONLY the slice'\''s `Status:` line to “🟡 In Progress” if the user runs `/apply`.

Emit two blocks:
A) The human-readable SLICE output.
B) A “PATCH PREVIEW” with the exact change to ROADMAP.md (Status line only). Do NOT apply until user says `/apply`.
Stop.

---

## 4) Verifier Agent (used by `/verify` and `/done`)
You are the **Verifier Agent**.
Input: a Slice ID and optional evidence command/output.
Task: check acceptance criteria from ROADMAP.md. If satisfied, mark Status ✅ Done; else propose the smallest check to collect evidence.

Rules:
- Never change goals/constraints.
- If evidence missing: suggest 1 command (or UI step) that would prove success/failure.
- When marking done, emit a patch that flips only that slice’s Status line.

Emit:

- Findings (one short paragraph)
- If complete: 
  <!-- PATCH START ROADMAP.md -->
  (unified diff changing "Status: ☐ Pending|�� In Progress" → "Status: ✅ Done")
  <!-- PATCH END ROADMAP.md -->
- If not complete: a single next check (command) and what success looks like.
Stop.
'

MACROS_MD='
# Slash Commands (repo-agnostic)

/clarify "<idea>" [--area path] [--constraints "a,b"] [--done "..."]
/plan <feature-id or title>
/slice <slice-id or ordinal>
/apply
/verify <slice-id> [--evidence "..."]
/done <slice-id>
/status
/revert <slice-id>

Guidance:
- Each command should produce an **append** or a **patch preview** that targets `.pipeline/ROADMAP.md`.
- Never rewrite history; only append or flip a Slice Status line.
'

CONTEXT_MD='
Always load:
- .pipeline/AGENTS.md
- .pipeline/MACROS.md
- .pipeline/CONTEXT.md
- .pipeline/ROADMAP.md
And any opened files in the editor.
'

ROADMAP_MD_HEADER=$(cat <<'ROADMAP'
# Project Roadmap

> Source of truth for features and SLICEs. Agents append below using APPEND blocks.

## Conventions
- One **Feature** → several **Slices** (each ≤ 30 minutes).
- Each slice has: Goal, Scope, Constraints, Steps, Acceptance, Status.
- Agents must only **append** or **patch Status lines**; no mass rewrites.

---

# Features
ROADMAP
)

# Example feature scaffold (gives you a starting pattern)
ROADMAP_MD_EXAMPLE=$(cat <<ROADMAP
<!-- FEATURE-START id:${FEATURE_ID} title: Example Feature -->
### Feature: Example Feature
**ID:** ${FEATURE_ID}  
**Area:** repo-wide  
**Constraints:** none  
**Definition of Done:** Demonstrate the multi-agent flow by creating, planning, slicing, and verifying a trivial task in this repo.

#### Slices
1. **S-${DATE}-001-1** — Create sentinel file
   Status: ☐ Pending
   - Goal: create \`.pipeline/SENTINEL\`
   - Scope: .pipeline/
   - Constraints: none
   - Steps:
     1) Add a 1-line file with timestamp
     2) Show command to verify existence
   - Acceptance:
     - File exists
     - \`cat .pipeline/SENTINEL\` shows timestamp
<!-- FEATURE-END -->
ROADMAP
)

VSCODE_TASKS=$(cat <<'VSCODE'
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "slice:run:streamlit",
      "type": "shell",
      "command": "streamlit run interface/main.py",
      "problemMatcher": [],
      "presentation": { "reveal": "always", "panel": "dedicated" }
    },
    {
      "label": "slice:test:python",
      "type": "shell",
      "command": "pytest -q ${input:expr}",
      "problemMatcher": [],
      "presentation": { "reveal": "always", "panel": "dedicated" }
    }
  ],
  "inputs": [
    { "id": "expr", "type": "promptString", "description": "pytest -k expression" }
  ]
}
VSCODE
)

# --------------------------
# Write files
# --------------------------
write_file ".pipeline/AGENTS.md" "$AGENTS_MD"
write_file ".pipeline/MACROS.md" "$MACROS_MD"
write_file ".pipeline/CONTEXT.md" "$CONTEXT_MD"

if [[ ! -f ".pipeline/ROADMAP.md" || $FORCE -eq 1 ]]; then
  write_file ".pipeline/ROADMAP.md" "$ROADMAP_MD_HEADER"$'\n\n'"$ROADMAP_MD_EXAMPLE"
else
  echo "• Skipped (exists): .pipeline/ROADMAP.md"
fi

if [[ $WITH_VSCODE -eq 1 ]]; then
  write_file ".vscode/tasks.json" "$VSCODE_TASKS"
fi

# Nice-to-have: add to .gitignore (non-destructive)
if [[ -f ".gitignore" ]]; then
  if ! grep -qE '^\s*# pipeline$' .gitignore 2>/dev/null; then
    {
      echo ""
      echo "# pipeline"
      echo ".pipeline/.cache/"
    } >> .gitignore
    echo "✓ Updated: .gitignore (added .pipeline/.cache/)"
  fi
fi

cat <<DONE

All set. Next steps:

1) In Claude Code, open this repo and pin:
   - .pipeline/AGENTS.md
   - .pipeline/MACROS.md
   - .pipeline/CONTEXT.md
   - .pipeline/ROADMAP.md

2) Try the ritual:
   /clarify "Wire auto-scan into Streamlit to process data_live and import to SQLite" --area interface --constraints "no new deps,no schema changes" --done "button scan, JSON produced, idempotent import"

3) Then:
   /plan F-${DATE}-001
   /slice S-${DATE}-001-1
   /apply
   /verify S-${DATE}-001-1 --evidence "ls .pipeline/SENTINEL && cat .pipeline/SENTINEL"
   /done S-${DATE}-001-1

Pro tip: commit these files so every collaborator gets the same rails.
DONE
