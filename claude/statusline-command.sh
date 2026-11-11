#!/usr/bin/env bash
# Claude Code status line — mirrors the \W PS1 prompt from ~/.bashrc

input=$(cat)

cwd=$(echo "$input" | jq -r '.cwd // empty')
dir=$(basename "$cwd")
model=$(echo "$input" | jq -r '.model.display_name // empty')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

line="$dir"

[ -n "$model" ] && line="$line | $model"

if [ -n "$used" ]; then
  used_int=$(printf '%.0f' "$used")
  line="$line | ctx: ${used_int}%"
fi

printf '%s' "$line"
