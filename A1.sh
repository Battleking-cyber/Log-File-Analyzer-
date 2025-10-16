#!/usr/bin/env bash
set -euo pipefail

timestamp() { date '+%Y%m%d_%H%M%S'; }

# Patterns (simple heuristics)
IP_RE='([0-9]{1,3}\.){3}[0-9]{1,3}'
ID_RE='([Uu]id=[A-Za-z0-9_.-]+|[Ii][Dd][[:space:]]*[:=][[:space:]]*[A-Za-z0-9_.-]+|user[ _-]?id[:=]?[[:space:]]*[A-Za-z0-9_.-]+)'
PWD_LINE_RE='password|pwd'   # case-insensitive used with grep -i

# Ask directory
read -rp "Enter directory to inspect (default .): " DIR
DIR=${DIR:-.}

if [[ ! -d "$DIR" ]]; then
  echo "Error: '$DIR' is not a directory." >&2
  exit 1
fi

# Globals for file list
print_file_list() {
  echo
  echo "Files in directory: $DIR"
  mapfile -t FILES < <(find "$DIR" -maxdepth 1 -type f -print | sort)
  if [[ ${#FILES[@]} -eq 0 ]]; then
    echo "  (no regular files found in $DIR)"
    exit 0
  fi
  for i in "${!FILES[@]}"; do
    printf "%3d) %s\n" "$((i+1))" "${FILES[$i]}"
  done
  echo
  echo "Enter file number to search, or 0 to search ALL listed files."
}

show_menu() {
  cat <<'MENU'

What would you like to search for in the selected file(s)?
  1) List log-like files (recursive)
  2) IP addresses (IPv4)
  3) IDs (uid=, ID:, user id, etc.)
  4) Password candidates (password, pwd)
  5) Search All three (IP, ID, Password)
  q) Quit / Back to file list

MENU
}

# Create result file
OUTFILE="search_results_$(timestamp).txt"
echo "Search started: $(date -R)" > "$OUTFILE"
echo "Directory: $DIR" >> "$OUTFILE"
echo "----------------------------------------" >> "$OUTFILE"

# Helper: append header to OUTFILE and print to screen
append_header() {
  local h="$1"
  echo >> "$OUTFILE"
  echo "===== $h =====" >> "$OUTFILE"
  printf "\n%s\n\n" "===== $h ====="
}

# Search helpers
search_ips_in_file() {
  local f="$1"
  append_header "IPs in $f"
  if ! grep -EnH --line-number -E "$IP_RE" "$f" 2>/dev/null; then
    echo "  (no IP matches in $f)" | tee -a "$OUTFILE"
  else
    # print matching lines + unique ip summary to OUTFILE
    grep -EnH --line-number -E "$IP_RE" "$f" 2>/dev/null | tee -a "$OUTFILE"
    echo >> "$OUTFILE"
    echo "Summary (unique IPs with counts):" >> "$OUTFILE"
    grep -Eo "$IP_RE" "$f" 2>/dev/null | sort | uniq -c | sort -rn | tee -a "$OUTFILE"
  fi
}

search_ids_in_file() {
  local f="$1"
  append_header "IDs in $f"
  if ! grep -EnH --line-number -E "$ID_RE" "$f" 2>/dev/null; then
    echo "  (no ID-like matches in $f)" | tee -a "$OUTFILE"
  else
    grep -EnH --line-number -E "$ID_RE" "$f" 2>/dev/null | tee -a "$OUTFILE"
    echo >> "$OUTFILE"
    echo "Summary (unique ID-like tokens with counts):" >> "$OUTFILE"
    grep -Eo "$ID_RE" "$f" 2>/dev/null | \
      sed -E 's/^[Uu]id=//; s/^[Ii][Dd][[:space:]]*[:=][[:space:]]*//; s/^user[ _-]?id[:=]?[[:space:]]*//' | \
      sort | uniq -c | sort -rn | tee -a "$OUTFILE"
  fi
}

search_passwords_in_file() {
  local f="$1"
  append_header "Password-related lines in $f"
  if ! grep -Ini --line-number -E "$PWD_LINE_RE" "$f" 2>/dev/null; then
    echo "  (no password/pwd matches in $f)" | tee -a "$OUTFILE"
  else
    # print matching lines to screen+outfile
    grep -Ini --line-number -E "$PWD_LINE_RE" "$f" 2>/dev/null | tee -a "$OUTFILE"
    echo >> "$OUTFILE"
    echo "Extracted tokens after common patterns (e.g. password=...):" >> "$OUTFILE"
    grep -Ini -E "$PWD_LINE_RE" "$f" 2>/dev/null | \
      sed -E 's/.*(password|pwd)[[:space:]]*[:=]?[[:space:]]*//I' | awk '{print $1}' | sort | uniq -c | sort -rn | tee -a "$OUTFILE"
  fi
}

# Main interactive loop
while true; do
  print_file_list

  read -rp $'Choose file number (or 0 for ALL, Ctrl-C to exit): ' FILE_CHOICE
  if ! [[ "$FILE_CHOICE" =~ ^[0-9]+$ ]]; then
    echo "Invalid input. Showing file list again."
    continue
  fi

  if [[ "$FILE_CHOICE" -eq 0 ]]; then
    TARGETS=("${FILES[@]}")
  else
    idx=$((FILE_CHOICE-1))
    if (( idx < 0 || idx >= ${#FILES[@]} )); then
      echo "Choice out of range. Showing file list again."
      continue
    fi
    TARGETS=( "${FILES[$idx]}" )
  fi

  # Action menu loop; invalid input returns to file list
  while true; do
    show_menu
    read -rp "Enter choice [1-5,q]: " ACTION
case "$ACTION" in
      1)
        echo
        echo "Log-like files under $DIR (recursive):"
        find "$DIR" -type f \( -iname '*.log' -o -iname '*.log.*' -o -iname '*.txt' -o -iname '*log*' \) -print | nl -w3 -ba
        echo
        echo "Returning to file list..."
        break
        ;;

      2)
        for f in "${TARGETS[@]}"; do
          if [[ ! -r "$f" ]]; then
            echo "Cannot read: $f" >&2
            continue
          fi
          search_ips_in_file "$f"
        done
        echo
        echo "Results appended to: $OUTFILE"
        read -rp "Press Enter to return to file list..." _ || true
        break
        ;;

      3)
        for f in "${TARGETS[@]}"; do
          if [[ ! -r "$f" ]]; then
            echo "Cannot read: $f" >&2
            continue
          fi
          search_ids_in_file "$f"
        done
        echo
        echo "Results appended to: $OUTFILE"
        read -rp "Press Enter to return to file list..." _ || true
        break
        ;;

      4)
        for f in "${TARGETS[@]}"; do
          if [[ ! -r "$f" ]]; then
            echo "Cannot read: $f" >&2
            continue
          fi
          search_passwords_in_file "$f"
        done
        echo
        echo "Results appended to: $OUTFILE"
        read -rp "Press Enter to return to file list..." _ || true
        break
        ;;

      5)
        for f in "${TARGETS[@]}"; do
          if [[ ! -r "$f" ]]; then
            echo "Cannot read: $f" >&2
            continue
          fi
          search_ips_in_file "$f"
          search_ids_in_file "$f"
          search_passwords_in_file "$f"
        done
        echo
        echo "All results appended to: $OUTFILE"
        read -rp "Press Enter to return to file list..." _ || true
        break
        ;;

      q|Q)
        echo "Going back to file list..."
        break
        ;;

      *)
        echo "Invalid choice — showing the file list again."
        break 2
        ;;
    esac
  done
done
