#!/usr/bin/env bash
set -euo pipefail

# Configuration
REPO="${GITHUB_REPOSITORY:-findingsov/nuts}"
DAYS_BACK="${DAYS_BACK:-21}"
OUTPUT_DIR="meetings"
OUTPUT_TO_FILE="${OUTPUT_TO_FILE:-true}"

if [[ -z "${REPO}" ]]; then
  echo "REPO not set and GITHUB_REPOSITORY is empty. Set REPO=owner/repo or run in GitHub Actions." >&2
  exit 1
fi

# Calculate date range (last N days)
SINCE_DATE_ONLY=$(date -u -d "${DAYS_BACK} days ago" +"%Y-%m-%d")  # GitHub search likes YYYY-MM-DD
SINCE_DATE_ISO=$(date -u -d "${DAYS_BACK} days ago" +"%Y-%m-%dT%H:%M:%SZ")
MEETING_DATE=$(if [[ $(date -u +%m) == 11 || $(date -u +%m) == 12 ]]; then date -u -d "$(date -u +%Y-%m-01) +2 weeks Thursday ${MEETING_TIME:-00:00}" +"%b %d %Y %H:%M UTC"; else NEXT_MONTH_FIRST=$(date -u -d "$(date -u +%Y-%m-01) +1 month" +%Y-%m-01); date -u -d "${NEXT_MONTH_FIRST} last Thursday ${MEETING_TIME:-00:00}" +"%b %d %Y %H:%M UTC"; fi); FILE_DATE=$(date -u +"%Y-%m-%d")
FILE_DATE=$(date -u +"%Y-%m-%d")

echo "Generating meeting agenda for ${MEETING_DATE}"
echo "Fetching data since ${SINCE_DATE_ISO}"

# Function to format PR/issue list
format_list() {
  local items="${1:-}"
  if [[ -z "$items" ]]; then
    echo "- None"
  else
    # shellcheck disable=SC2002
    echo "$items" | while IFS=$'\t' read -r number title url; do
      echo "- [#${number}](${url}) - ${title}"
    done
  fi
}

# Fetch merged PRs
echo "Fetching merged PRs..."
MERGED_PRS=$(gh pr list \
  --repo "$REPO" \
  --state merged \
  --search "merged:>=${SINCE_DATE_ONLY}" \
  --json number,title,url \
  --jq '.[] | [.number, .title, .url] | @tsv' \
  2>/dev/null || echo "")

# Fetch new PRs (opened in the last N days)
echo "Fetching new PRs..."
NEW_PRS=$(gh pr list \
  --repo "$REPO" \
  --state open \
  --search "created:>=${SINCE_DATE_ONLY}" \
  --json number,title,url \
  --jq '.[] | [.number, .title, .url] | @tsv' \
  2>/dev/null || echo "")

# Generate markdown
AGENDA="$(
cat <<EOF
# NUTS update

${MEETING_DATE}

## Merged

$(format_list "$MERGED_PRS")

## New PRs

$(format_list "$NEW_PRS")
EOF
)"

echo "$AGENDA"

# Output to file if requested
OUTPUT_FILE=""
if [[ "${OUTPUT_TO_FILE}" == "true" ]]; then
  mkdir -p "$OUTPUT_DIR"
  OUTPUT_FILE="${OUTPUT_DIR}/${FILE_DATE}-agenda.md"
  echo "$AGENDA" > "$OUTPUT_FILE"
  echo "Agenda saved to $OUTPUT_FILE"
fi

# Output for GitHub Actions
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  if [[ -n "$OUTPUT_FILE" ]]; then
    echo "agenda_file=$OUTPUT_FILE" >> "$GITHUB_OUTPUT"
  fi
  echo "meeting_date=$MEETING_DATE" >> "$GITHUB_OUTPUT"
fi
