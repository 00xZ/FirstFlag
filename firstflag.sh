#!/usr/bin/env bash
set -euo pipefail

QUICK_MODE=false
SINGLE_MODE=true
QUICK_PORTS="${QUICK_PORTS:-22,80,443}"
TARGET_DIR=""
TARGET_IP=""
VHOST_DOMAIN=""

print_banner() {
    printf '\033[1;36m'
print_banner() {
    printf '\033[1;36m'
    printf '\033[1;36m'
    echo "    "
    echo "   o________"
    echo "   |01001111|  "
    echo "   |01011010|  "
    echo "   |"
    echo "   |"
    echo "   |     ~~FirstFlag~~"
    echo "           ~Eyezik~ "
    echo "    "
    echo "   " #yes im sure i can do \n in some way but im lazy
    printf '\033[0m\n'
}
    printf '\033[0m\n'
}

usage() {
    echo "Usage: $0 [-q|--quick] [-p|--parallel] [-o|--output <dir>] [-h|--help] <target_ip> [vhost_base_domain]"
    echo "  -q, --quick     Skip the full port sweep, scan only \$QUICK_PORTS"
    echo "                  (default: 22,80,443 - override by setting \$QUICK_PORTS)"
    echo "  -p, --parallel  Open separate terminals for each job."
    echo "  -o, --output    Specify output directory (default: /root/htb/<target_ip>)"
    echo "  -h, --help      Display this help message and exit"
    echo "  "
    echo "Example: $0 -o /root/htb/nexus 10.10.11.45 target.htb"
    echo "Example: $0 --quick 10.10.11.45 target.htb"
    echo "Most used by me: $0 --quick -o /root/htb/nexus 10.10.11.45 target.htb"
}

# Parse arguments cleanly
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -q|--quick)
            QUICK_MODE=true
            shift
            ;;
        -s|--single)
            SINGLE_MODE=true
            shift
            ;;
        -p|--parallel)
            SINGLE_MODE=false
            shift
            ;;
        -o|--output)
            TARGET_DIR="$2"
            shift 2
            ;;
        -*|--*)
            echo "[!] Unknown option: $1"
            echo
            usage
            exit 1
            ;;
        *)
            if [[ -z "$TARGET_IP" ]]; then
                TARGET_IP="$1"
            elif [[ -z "$VHOST_DOMAIN" ]]; then
                VHOST_DOMAIN="$1"
            else
                echo "[!] Unexpected extra argument: $1"
                exit 1
            fi
            shift
            ;;
    esac
done

if [[ -z "$TARGET_IP" ]]; then
    usage
    exit 1
fi
print_banner

# Default output directory if not specified via -o
if [[ -z "$TARGET_DIR" ]]; then
    TARGET_DIR="/root/htb/$TARGET_IP"
fi
# Default output directory if not specified via -o
if [[ -z "$TARGET_DIR" ]]; then
    TARGET_DIR="/root/htb/$TARGET_IP"
fi

SUBLIST_REL="Discovery/DNS/subdomains-top1million-110000.txt"
if [[ -n "${WORDLIST:-}" ]]; then
    :
elif [[ -f "$HOME/SecLists/$SUBLIST_REL" ]]; then
    WORDLIST="$HOME/SecLists/$SUBLIST_REL"
elif [[ -f "/usr/share/seclists/$SUBLIST_REL" ]]; then
    WORDLIST="/usr/share/seclists/$SUBLIST_REL"
elif [[ -f "/usr/share/SecLists/$SUBLIST_REL" ]]; then
    WORDLIST="/usr/share/SecLists/$SUBLIST_REL"
elif [[ -f "/opt/SecLists/$SUBLIST_REL" ]]; then
    WORDLIST="/opt/SecLists/$SUBLIST_REL"
else
    FOUND=$(find / -maxdepth 6 -iname "subdomains-top1million-110000.txt" -print -quit 2>/dev/null || true)
    WORDLIST="$FOUND"
fi

if [[ -n "$WORDLIST" ]]; then
    echo "[*] Wordlist: $WORDLIST"
else
    echo "[!] SecLists wordlist not found."
fi

mkdir -p "$TARGET_DIR"
JOBS_DIR="$TARGET_DIR/.jobs"
mkdir -p "$JOBS_DIR"

SCAN_FILE="$TARGET_DIR/scan.txt"
VHOST_JSON="$TARGET_DIR/vhost.json"
SUBDOMAINS_FILE="$TARGET_DIR/valid_subdomains.txt"
FINDINGS_FILE="$TARGET_DIR/findings.txt"
NMAP_DONE="$TARGET_DIR/.nmap.done"
FFUF_DONE="$TARGET_DIR/.ffuf.done"

echo "[*] Output: $TARGET_DIR"
echo "[*] Target: $TARGET_IP"
echo "[*] Vhost: ${VHOST_DOMAIN:-skipped}"
if [[ "$QUICK_MODE" == true ]]; then
    echo "[*] Quick scan: $QUICK_PORTS"
else
    echo "[*] Full port scan"
fi
echo

NMAP_JOB="$JOBS_DIR/nmap_job.sh"
if [[ "$QUICK_MODE" == true ]]; then
cat > "$NMAP_JOB" << JOB_EOF
#!/usr/bin/env bash
set -euo pipefail

TMP_DETAIL=\$(mktemp)
trap 'rm -f "\$TMP_DETAIL"' EXIT

echo "[nmap] Scanning $QUICK_PORTS..."
nmap -sC -sV -p"$QUICK_PORTS" -Pn "$TARGET_IP" | tee "\$TMP_DETAIL"

{
  printf '\033[1;36m================================================\033[0m\n'
  printf '\033[1;36m  nmap recon (quick) — $TARGET_IP\033[0m\n'
  printf '\033[1;36m  %s\033[0m\n' "\$(date)"
  printf '\033[1;36m================================================\033[0m\n\n'

  cat "\$TMP_DETAIL"

  echo
  printf '\033[1;33m================ NOTABLE LINES ================\033[0m\n'
  grep -iE 'vulnerable|CVE-[0-9]|anonymous|allowed|login|title:|robots|redirect|ssl-cert|smb-|warning|insecure|default cred|outdated|disclosure' "\$TMP_DETAIL" || echo "(nothing flagged — eyeball the full scan above)"

  echo
  printf '\033[1;32m================= OPEN PORTS ==================\033[0m\n'
  grep -E '^[0-9]+/[a-z]+' "\$TMP_DETAIL" | grep -i open || echo "(none of $QUICK_PORTS showed open - try without --quick)"
  printf '\033[1;32m================================================\033[0m\n'
} > "$SCAN_FILE"

echo "nmap done (quick)" > "$NMAP_DONE"
echo
echo "[+] nmap complete (quick mode). Pretty summary written to: $SCAN_FILE"
JOB_EOF
else
cat > "$NMAP_JOB" << JOB_EOF
#!/usr/bin/env bash
set -euo pipefail

TMP_SWEEP=\$(mktemp)
TMP_DETAIL=\$(mktemp)
trap 'rm -f "\$TMP_SWEEP" "\$TMP_DETAIL"' EXIT

echo "[nmap] Scanning all TCP ports..."
nmap -p- --min-rate=5000 -T4 -Pn "$TARGET_IP" -oG "\$TMP_SWEEP" >/dev/null

OPEN_PORTS=\$(grep -oP '\d+(?=/open)' "\$TMP_SWEEP" | sort -nu | paste -sd, -)

if [[ -z "\$OPEN_PORTS" ]]; then
    echo "No open TCP ports found on $TARGET_IP." > "$SCAN_FILE"
    echo "nmap done, no ports open" > "$NMAP_DONE"
    cat "$SCAN_FILE"
    echo
    exit 0
fi
echo "[+] Open ports: \$OPEN_PORTS"

echo "[nmap] Detecting services..."
nmap -sC -sV -p"\$OPEN_PORTS" -Pn "$TARGET_IP" | tee "\$TMP_DETAIL"

{
  printf '\033[1;36m================================================\033[0m\n'
  printf '\033[1;36m  nmap recon — $TARGET_IP\033[0m\n'
  printf '\033[1;36m  %s\033[0m\n' "\$(date)"
  printf '\033[1;36m================================================\033[0m\n\n'

  cat "\$TMP_DETAIL"

  echo
  printf '\033[1;33m================ NOTABLE LINES ================\033[0m\n'
  grep -iE 'vulnerable|CVE-[0-9]|anonymous|allowed|login|title:|robots|redirect|ssl-cert|smb-|warning|insecure|default cred|outdated|disclosure' "\$TMP_DETAIL" || echo "(nothing flagged — eyeball the full scan above)"

  echo
  printf '\033[1;32m================= OPEN PORTS ==================\033[0m\n'
  grep -E '^[0-9]+/[a-z]+' "\$TMP_DETAIL"
  printf '\033[1;32m================================================\033[0m\n'
} > "$SCAN_FILE"

echo "nmap done" > "$NMAP_DONE"
echo
echo "[+] nmap complete. Pretty summary written to: $SCAN_FILE"
JOB_EOF
fi
chmod +x "$NMAP_JOB"

FFUF_JOB="$JOBS_DIR/ffuf_job.sh"
cat > "$FFUF_JOB" << JOB_EOF
#!/usr/bin/env bash
set -euo pipefail
if [[ -z "$VHOST_DOMAIN" ]]; then
    echo "[ffuf] Skipped (no domain)."
    echo "ffuf done, nothing to fuzz" > "$FFUF_DONE"
    exit 0
fi
if [[ ! -f "$WORDLIST" ]]; then
    echo "[!] Wordlist not found: $WORDLIST"
    echo "ffuf done, no wordlist" > "$FFUF_DONE"
    exit 1
fi

echo "[ffuf] Fuzzing $VHOST_DOMAIN..."
ffuf -u "http://$VHOST_DOMAIN" \
     -w "$WORDLIST" \
     -H "HOST: FUZZ.$VHOST_DOMAIN" \
     -mc all \
     -ac \
     -of json -o "$VHOST_JSON" \
     -s

echo "ffuf done" > "$FFUF_DONE"
echo

if ! command -v jq &>/dev/null; then
    echo "[!] jq not found; raw results saved."
    exit 0
fi

TMP_HOSTS=\$(mktemp)
jq -r --arg d "$VHOST_DOMAIN" '.results[] | "\(.input.FUZZ).\(\$d)"' "$VHOST_JSON" \
    | sort -u > "\$TMP_HOSTS"
COUNT=\$(wc -l < "\$TMP_HOSTS")
echo "[+] \$COUNT vhost(s) survived autocalibration."

if [[ "\$COUNT" -eq 0 ]]; then
    > "$SUBDOMAINS_FILE"
    rm -f "\$TMP_HOSTS"
    exit 0
fi

if command -v httpx &>/dev/null; then
    echo "[ffuf] probing \$COUNT host(s) with httpx (-title -sc -fr)..."
    httpx -l "\$TMP_HOSTS" -title -sc -fr -silent > "$SUBDOMAINS_FILE" 2>/dev/null || true
    echo "[+] Saved: $SUBDOMAINS_FILE"
    cat "$SUBDOMAINS_FILE"
else
    echo "[!] httpx not found; saving hostnames only."
    cp "\$TMP_HOSTS" "$SUBDOMAINS_FILE"
    cat "$SUBDOMAINS_FILE"
fi
rm -f "\$TMP_HOSTS"

echo
echo "[*] Add any discovered hosts to /etc/hosts manually if needed."
JOB_EOF
chmod +x "$FFUF_JOB"

VULN_JOB="$JOBS_DIR/vuln_job.sh"
cat > "$VULN_JOB" << JOB_EOF
#!/usr/bin/env bash
set -euo pipefail

echo "[vuln] Waiting for scans..."
while [[ ! -f "$NMAP_DONE" ]]; do
    sleep 2
done
while [[ ! -f "$FFUF_DONE" ]]; do
    sleep 2
done

{
  printf '\033[1;35m================================================\033[0m\n'
  printf '\033[1;35m  vulnerability lookup — $TARGET_IP\033[0m\n'
  printf '\033[1;35m  %s\033[0m\n' "\$(date)"
  printf '\033[1;35m================================================\033[0m\n'
} > "$FINDINGS_FILE"

if command -v searchsploit &>/dev/null; then
    echo "[vuln] Running SearchSploit..."
    {
      echo
      printf '\033[1;33m---------------- searchsploit -------------------\033[0m\n'
    } >> "$FINDINGS_FILE"
    HITS=0
    while IFS= read -r line; do
        SVC=\$(echo "\$line" | awk '{for(i=4;i<=NF;i++) printf "%s ", \$i}' | sed 's/[[:space:]]*\$//')
        [[ -z "\$SVC" ]] && continue
        RESULT=\$(searchsploit "\$SVC" 2>/dev/null || true)
        if [[ -n "\$RESULT" ]] && ! echo "\$RESULT" | grep -q "No Results"; then
            HITS=\$((HITS+1))
            {
              echo "--- \$SVC ---"
              echo "\$RESULT"
              echo
            } >> "$FINDINGS_FILE"
        fi
    done < <(grep -E '^[0-9]+/[a-z]+ +open' "$SCAN_FILE" 2>/dev/null || true)
    [[ "\$HITS" -eq 0 ]] && echo "(no searchsploit matches for detected versions)" >> "$FINDINGS_FILE"
else
    echo "[!] SearchSploit not found; skipping." >> "$FINDINGS_FILE"
fi

if grep -qE '^(80|443)/tcp +open' "$SCAN_FILE" 2>/dev/null; then
    if command -v nuclei &>/dev/null; then
        echo "[vuln] Running Nuclei..."
        {
          echo
          printf '\033[1;33m-------------------- nuclei ---------------------\033[0m\n'
        } >> "$FINDINGS_FILE"
        TARGETS_FILE=\$(mktemp)
        echo "http://$TARGET_IP" > "\$TARGETS_FILE"
        grep -qE '^443/tcp +open' "$SCAN_FILE" && echo "https://$TARGET_IP" >> "\$TARGETS_FILE"
        if [[ -n "$VHOST_DOMAIN" ]]; then
            echo "http://$VHOST_DOMAIN" >> "\$TARGETS_FILE"
        fi
        if [[ -s "$SUBDOMAINS_FILE" ]]; then
            echo "[vuln] Including discovered hosts..."
            awk '{print \$1}' "$SUBDOMAINS_FILE" | while IFS= read -r sub; do
                echo "http://\$sub" >> "\$TARGETS_FILE"
            done
        fi
        sort -u "\$TARGETS_FILE" -o "\$TARGETS_FILE"
        nuclei -l "\$TARGETS_FILE" -silent -severity low,medium,high,critical >> "$FINDINGS_FILE" 2>/dev/null || true
        rm -f "\$TARGETS_FILE"
    else
        echo "[!] Nuclei not found; skipping." >> "$FINDINGS_FILE"
    fi
else
    echo "[*] No web ports found; skipping Nuclei." >> "$FINDINGS_FILE"
fi

echo
echo "[+] Findings: $FINDINGS_FILE"
cat "$FINDINGS_FILE"
echo
JOB_EOF
chmod +x "$VULN_JOB"

launch_parallel() {
    if [[ "$SINGLE_MODE" == true ]]; then
        echo "[*] Running jobs in this terminal..."
        bash "$NMAP_JOB"
        bash "$FFUF_JOB"
        bash "$VULN_JOB"
    elif command -v gnome-terminal &>/dev/null; then
        echo "[*] Launching separate terminals..."
        gnome-terminal --title="nmap: $TARGET_IP" -- bash "$NMAP_JOB"
        gnome-terminal --title="ffuf: ${VHOST_DOMAIN:-skip}" -- bash "$FFUF_JOB"
        gnome-terminal --title="vuln: $TARGET_IP" -- bash "$VULN_JOB"
    elif command -v xterm &>/dev/null; then
        echo "[*] Launching separate terminals..."
        xterm -T "nmap: $TARGET_IP" -e bash "$NMAP_JOB" &
        xterm -T "ffuf: ${VHOST_DOMAIN:-skip}" -e bash "$FFUF_JOB" &
        xterm -T "vuln: $TARGET_IP" -e bash "$VULN_JOB" &
    elif command -v tmux &>/dev/null; then
        echo "[*] Using tmux..."
        SESSION="htb_$(basename "$TARGET_DIR")_$$"
        tmux new-session -d -s "$SESSION" -n nmap "bash '$NMAP_JOB'"
        tmux new-window -t "$SESSION" -n ffuf "bash '$FFUF_JOB'"
        tmux new-window -t "$SESSION" -n vuln "bash '$VULN_JOB'"
        echo "[*] Attaching to tmux session $SESSION."
        tmux attach -t "$SESSION"
    else
        echo "[!] No terminal multiplexer found; running here."
        bash "$NMAP_JOB"
        bash "$FFUF_JOB"
        bash "$VULN_JOB"
    fi
}

launch_parallel

echo
echo "[+] Output files: $TARGET_DIR"
echo "    scan.txt, valid_subdomains.txt, findings.txt"
