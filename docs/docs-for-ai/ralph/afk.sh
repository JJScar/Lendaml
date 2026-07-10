#!/bin/bash
set -eo pipefail

if [ -z "$1" ]; then
  echo "Usage: $0 <iterations>  (run from the project root)"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# jq filter to extract streaming text, plus a progress line for tool calls
# (otherwise long-running tools like SDK installs look like a silent hang)
stream_text='
  (
    if .type == "assistant" then
      .message.content[]? |
      if .type == "text" then .text
      elif .type == "tool_use" then
        "\n$ " + .name + (
          if .input.command then ": " + .input.command
          elif .input.file_path then ": " + .input.file_path
          else "" end
        )
      else empty end
    elif .type == "user" then
      .message.content[]? | select(.type == "tool_result") | "  ...done"
    else empty end
  ) | select(. != null) | gsub("\n"; "\r\n") | . + "\r\n\n"
'

# jq filter to extract final result
final_result='select(.type == "result").result // empty'

for ((i=1; i<=$1; i++)); do
  tmpfile=$(mktemp)
  trap "rm -f $tmpfile" EXIT

  commits=$(git log -n 5 --format="%H%n%ad%n%B---" --date=short 2>/dev/null || echo "No commits found")
  tickets=$(cat tickets.md 2>/dev/null || echo "No tickets found")
  prompt=$(cat "$SCRIPT_DIR/prompt.md")

  docker sandbox run claude . -- \
    --verbose \
    --print \
    --output-format stream-json \
    "Previous commits: $commits Tickets: $tickets $prompt" \
  | grep --line-buffered '^{' \
  | tee "$tmpfile" \
  | jq --unbuffered -rj "$stream_text"

  result=$(jq -r "$final_result" "$tmpfile")

  if [[ "$result" == *"<promise>NO MORE TASKS</promise>"* ]]; then
    echo "Ralph complete after $i iterations."
    exit 0
  fi
done