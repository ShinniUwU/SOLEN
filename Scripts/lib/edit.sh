#!/usr/bin/env bash
# Minimal editing helpers for marker-managed blocks

# Insert or replace a marker block in a file
# usage: solen_insert_marker_block <file> <begin_marker> <end_marker> <content>
solen_insert_marker_block() {
  local file="$1" begin="$2" end="$3" content="$4"
  mkdir -p "$(dirname "$file")" 2>/dev/null || true
  touch "$file"
  # Remove existing block
  tmpfile="${file}.tmp.$$"
  awk -v b="$begin" -v e="$end" '
    BEGIN{inblk=0}
    { if(index($0,b)==1){inblk=1; next} }
    { if(index($0,e)==1){inblk=0; next} }
    { if(inblk==0) print $0 }
  ' "$file" > "$tmpfile"
  mv "$tmpfile" "$file"
  # Ensure newline at EOF
  tail -c1 "$file" 2>/dev/null | read -r _ || echo >> "$file"
  {
    echo "$begin"
    printf "%s\n" "$content"
    echo "$end"
  } >> "$file"
}

# Remove a marker block from a file (no error if absent)
solen_remove_marker_block() {
  local file="$1" begin="$2" end="$3"
  [ -f "$file" ] || return 0
  tmpfile="${file}.tmp.$$"
  awk -v b="$begin" -v e="$end" '
    BEGIN{inblk=0}
    { if(index($0,b)==1){inblk=1; next} }
    { if(index($0,e)==1){inblk=0; next} }
    { if(inblk==0) print $0 }
  ' "$file" > "$tmpfile"
  mv "$tmpfile" "$file"
}

