# 🚩 FirstFLag

> Starting a CTF can be redundant. FirstFlag is my solution.

---

## 🚀 Hows it work

* **Automated Recon Pipeline:** Orchestrates `nmap` port sweeps/service scans, `ffuf` vhost fuzzing, and automated checks in a streamlined workflow.
* **Smart Wordlist Detection:** Automatically checks common paths (SecLists, home directory, etc.) for `subdomains-top1million-110000.txt`.
* **Vulnerability Correlation:** Automatically pipes open service versions into `searchsploit` and runs `nuclei` against discovered web targets.
* **Flexible Execution:** Supports quick scanning modes, custom output directories, and parallel terminal multiplexing (`tmux`, `gnome-terminal`, or `xterm`).

---
### 💡 Usage Examples

> 📌 **Tip:** For fast-paced CTF environments or active Hack The Box machines, use **Quick Mode (`-q`)** to target essential ports immediately before launching full scans.

#### ⚡ Quick & Custom Directory *(Recommended)*
Run a quick sweep on essential ports and store results in a custom folder:

### Examples

- **Quick mode with a custom output directory (Most common):**
```bash
    ./firstflag.sh --quick -o /root/htb/nexus 10.10.11.45 target.htb
```
- **Standard run (Full TCP scan + vhost fuzzing):**
 ```bash
    ./firstflag.sh 10.10.11.45 target.htb
```
- **Parallel execution mode (Runs scans in separate terminal windows):**
```bash
    ./firstflag.sh --parallel 10.10.11.45 target.htb
```
- **Standalone IP scan (No virtual host fuzzing):**
```bash
    ./firstflag.sh 10.10.11.45
```

## ⚙️ Prerequisites

Ensure you have the following tools installed and available in your `$PATH`:
* `nmap`
* `ffuf`
* `jq`
* `searchsploit` *(optional)*
* `nuclei` *(optional)*
* `httpx` *(optional)*
* **SecLists** wordlists

---

## 📥 Installation

1. Clone your repository:
   ```bash
   git clone [https://github.com/00xZ/FirstFlag.git](https://github.com/00xZ/FirstFlag.git)
   cd FirstFlag
   chmod +x +.sh
   ./install.sh
## 🚀 Features

- **Automated Recon Pipeline:** Orchestrates `nmap` port sweeps/service scans, `ffuf` vhost fuzzing, and automated checks in a streamlined workflow.
- **Smart Wordlist Detection:** Automatically checks common paths (SecLists, home directory, etc.) for `subdomains-top1million-110000.txt`.
- **Vulnerability Correlation:** Automatically pipes open service versions into `searchsploit` and runs `nuclei` against discovered web targets.
- **Flexible Execution:** Supports quick scanning modes, custom output directories, and parallel terminal multiplexing (`tmux`, `gnome-terminal`, or `xterm`).

---

## ⚙️ Prerequisites

Ensure you have the following tools installed and available in your `$PATH`:
- `nmap`
- `ffuf`
- `jq`
- `searchsploit` *(optional)*
- `nuclei` *(optional)*
- `httpx` *(optional)*
- **SecLists** wordlists

---

## 💡 Usage

    Usage: ./firstflag.sh [-q|--quick] [-p|--parallel] [-o|--output <dir>] [-h|--help] <target_ip> [vhost_base_domain]

### Examples

- **Quick mode with a custom output directory (Most common):**
    ./firstflag.sh --quick -o /root/htb/nexus 10.10.11.45 target.htb

- **Standard run (Full TCP scan + vhost fuzzing):**
    ./firstflag.sh 10.10.11.45 target.htb

- **Parallel execution mode (Runs scans in separate terminal windows):**
    ./firstflag.sh --parallel 10.10.11.45 target.htb

- **Standalone IP scan (No virtual host fuzzing):**
    ./firstflag.sh 10.10.11.45

- **Quick sweep with default output path (`/root/htb/<IP>`):**
    ./firstflag.sh --quick 10.10.11.45

### Options

- `-q`, `--quick` — Skip the full port sweep, scan only `$QUICK_PORTS` (default: `22,80,443`).
- `-p`, `--parallel` — Open separate terminal windows/panes for each job.
- `-o`, `--output` — Specify a custom output directory (default: `/root/htb/<target_ip>`).
- `-h`, `--help` — Display the help message and exit.

- **Quick sweep with default output path (`/root/htb/<IP>`):**
```bash
    ./firstflag.sh --quick 10.10.11.45
```
## 📂 Output Structure

The tool creates a dedicated workspace directory containing:
- `scan.txt` — Pretty-printed `nmap` scan summary and notable findings.
- `vhost.json` — Raw `ffuf` virtual host fuzzing results.
- `valid_subdomains.txt` — Discovered subdomains (probed via `httpx` if available).
- `findings.txt` — Correlated `searchsploit` hits and `nuclei` vulnerability scans.

---

## 👤 Author

- **Eyezol** — GitHub ([@00xZ](https://github.com/00xZ))

valid_subdomains.txt — Discovered subdomains (probed via httpx if available).

findings.txt — Correlated searchsploit hits and nuclei vulnerability scans.
