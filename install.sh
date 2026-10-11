```bash
#!/usr/bin/env bash
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "[!] Run this script with sudo."
    exit 1
fi

if ! command -v apt-get &>/dev/null; then
    echo "[!] apt-get not found. This script requires a Debian-based distro."
    exit 1
fi

apt-get update -qq

install_pkg() {
    local bin="$1"
    local pkg="$2"

    if command -v "$bin" &>/dev/null; then
        echo "[=] $bin is already installed."
    else
        echo "[*] Installing $pkg..."
        apt-get install -y -qq "$pkg"
    fi
}

install_pkg nmap nmap
install_pkg ffuf ffuf
install_pkg jq jq
install_pkg tmux tmux
install_pkg xterm xterm
install_pkg curl curl
install_pkg unzip unzip
install_pkg searchsploit exploitdb

if [[ -f /usr/share/seclists/Discovery/DNS/subdomains-top1million-110000.txt ]] ||
   [[ -f "$HOME/SecLists/Discovery/DNS/subdomains-top1million-110000.txt" ]]; then
    echo "[=] SecLists is already installed."
else
    echo "[*] Installing SecLists..."
    apt-get install -y -qq seclists 2>/dev/null || {
        echo "[!] Installing SecLists from GitHub..."
        git clone --depth 1 https://github.com/danielmiessler/SecLists.git "$HOME/SecLists"
    }
fi

if ! command -v gnome-terminal &>/dev/null; then
    echo "[*] Installing gnome-terminal..."
    apt-get install -y -qq gnome-terminal 2>/dev/null ||
        echo "[!] Could not install gnome-terminal."
fi

if ! command -v nuclei &>/dev/null; then
    ARCH="$(uname -m)"

    case "$ARCH" in
        x86_64) NUCLEI_ARCH="amd64" ;;
        aarch64) NUCLEI_ARCH="arm64" ;;
        armv7l) NUCLEI_ARCH="arm" ;;
        *)
            echo "[!] Unsupported architecture: $ARCH"
            NUCLEI_ARCH=""
            ;;
    esac

    if [[ -n "$NUCLEI_ARCH" ]]; then
        VERSION=$(curl -sL -o /dev/null -w '%{url_effective}' \
            https://github.com/projectdiscovery/nuclei/releases/latest |
            grep -oP '(?<=tag/v)[^/]+')

        if [[ -n "$VERSION" ]]; then
            URL="https://github.com/projectdiscovery/nuclei/releases/download/v${VERSION}/nuclei_${VERSION}_linux_${NUCLEI_ARCH}.zip"
            TMP_ZIP=$(mktemp --suffix=.zip)

            if curl -sL -f "$URL" -o "$TMP_ZIP"; then
                unzip -oq "$TMP_ZIP" -d /usr/local/bin nuclei
                chmod +x /usr/local/bin/nuclei
                echo "[+] Installed nuclei v${VERSION}"
            else
                echo "[!] Failed to download nuclei."
            fi

            rm -f "$TMP_ZIP"
        else
            echo "[!] Could not determine the latest nuclei version."
        fi
    fi
else
    echo "[=] nuclei is already installed."
fi

if command -v nuclei &>/dev/null; then
    echo "[*] Updating nuclei templates..."
    nuclei -update-templates -silent ||
        echo "[!] Template update failed."
fi

echo
echo "[+] Installation check"

for bin in nmap ffuf jq tmux xterm searchsploit nuclei; do
    if command -v "$bin" &>/dev/null; then
        echo "[x] $bin"
    else
        echo "[ ] $bin is missing"
    fi
done

if command -v gnome-terminal &>/dev/null; then
    echo "[x] gnome-terminal"
else
    echo "[ ] gnome-terminal (optional)"
fi

if [[ -f /usr/share/seclists/Discovery/DNS/subdomains-top1million-110000.txt ]] ||
   [[ -f "$HOME/SecLists/Discovery/DNS/subdomains-top1million-110000.txt" ]]; then
    echo "[x] SecLists"
else
    echo "[ ] SecLists is missing"
fi

echo
echo "[+] Done. Run recon.sh to get started."
```
