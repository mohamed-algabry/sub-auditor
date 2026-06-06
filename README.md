# 🌐 Subdomain Audit Toolkit

A modular, zero‑bloat **Bash** script that automates subdomain reconnaissance for a given domain.  
It discovers subdomains using multiple passive sources, checks which ones are alive, captures screenshots of live web services, and runs a service scan on the resolved IP addresses.

> **Author**: [Your Name]  
> **License**: MIT  
> **Status**: Production‑ready  

---

![GitHub release (latest by date)](https://img.shields.io/github/v/release/yourusername/subdomain-audit)
![Shell](https://img.shields.io/badge/Shell-Bash-4EAA25?logo=gnu-bash&logoColor=white)
![Dependencies](https://img.shields.io/badge/dependencies-optional-brightgreen)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen)](CONTRIBUTING.md)

---

## 📋 Table of Contents

- [Features](#-features)
- [Workflow Overview](#-workflow-overview)
- [Prerequisites & Dependencies](#-prerequisites--dependencies)
- [Installation](#-installation)
- [Usage](#-usage)
- [Output Structure](#-output-structure)
- [Customization](#-customization)
- [Example Run](#-example-run)
- [Ethical Use & Disclaimer](#-ethical-use--disclaimer)
- [Acknowledgements](#-acknowledgements)

---

## ✨ Features

- **Multi‑source subdomain discovery** – leverages `subfinder`, `assetfinder`, `amass`, and `findomain` (falls back gracefully if any are missing).
- **Reliable deduplication** – pure shell extraction and sorting without external dependencies.
- **Live host verification** – built‑in Python 3 script checks HTTP/HTTPS responses with a 10‑second timeout.
- **Screenshot capture** – uses `gowitness` or Playwright (via `npx`) to grab visual proof of live web services.
- **Nmap service scan** – resolves live hosts to IPs and runs a version detection scan (`-sV`) on open ports.
- **Clean, structured output** – all results are stored in a timestamp‑friendly folder (`subdomain_audit_<domain>`).
- **Error‑resilient** – `set -euo pipefail` and per‑tool `|| true` ensure the script never breaks mid‑flight.

---

## 🔄 Workflow Overview

1. **Subdomain Discovery** – queries multiple passive APIs and compiles a unique list.
2. **Alive Check** – tests each subdomain over both HTTP and HTTPS, keeping only those that respond with a 2xx/3xx status.
3. **Screenshots** – renders each live host using a headless browser.
4. **Nmap Scan** – resolves domains → IPs, then performs a service/version scan on all resolved addresses.

---

## 📦 Prerequisites & Dependencies

All external tools are **optional** – the script detects which are installed and adapts. However, for a full audit you’ll want most of them.

### Core requirement
- **Bash** ≥ 4.0 (Linux/macOS)
- **Python 3** (used internally for alive checking and DNS resolution)

### Recommended tools

| Tool         | Purpose                     | Installation                                  |
|--------------|-----------------------------|-----------------------------------------------|
| `subfinder`  | Passive subdomain enum      | `go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest` |
| `assetfinder`| Subdomain enum              | `go install -v github.com/tomnomnom/assetfinder@latest` |
| `amass`      | Passive enumeration         | `sudo apt install amass` / `brew install amass` |
| `findomain`  | Fast subdomain enum         | [GitHub releases](https://github.com/Findomain/Findomain) |
| `gowitness`  | Screenshot capture          | `go install -v github.com/sensepost/gowitness@latest` |
| `playwright` | Screenshot fallback (via npx) | `npm install -g playwright` (or auto‑fetched by `npx`) |
| `nmap`       | Service/port scan           | `sudo apt install nmap` / `brew install nmap`   |

> 💡 All Go tools can be installed with `go install <module>@latest`. Make sure `$GOPATH/bin` is in your `PATH`.

### Quick install (Debian/Ubuntu)

```bash
# System packages
sudo apt update && sudo apt install nmap amass golang python3 -y

# Go tools
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install -v github.com/tomnomnom/assetfinder@latest
go install -v github.com/sensepost/gowitness@latest
# For findomain, download the binary from https://github.com/Findomain/Findomain/releases
```

## 💻 Installation

Clone the repository and make the script executable:

```bash
git clone [https://github.com/yourusername/subdomain-audit.git](https://github.com/yourusername/subdomain-audit.git)
cd subdomain-audit
chmod +x subdomain_audit.sh
```

## 🚀 Usage

Run the script and pass the target domain as the only argument:

```bash
./subdomain_audit.sh example.com
```

Arguments:

Argument	Description	Required?
<domain>	The domain to audit (e.g., example.com)	Yes
Example:

```bash
./subdomain_audit.sh tesla.com
```
The tool will create a directory named subdomain_audit_tesla_com/ (sanitised domain name) and store all results inside.

## 📂 Output Structure

After a successful run, the working directory contains:

```text
subdomain_audit_example_com/
├── raw_subdomains.txt        # All discovered subdomains before dedup
├── subdomains.txt            # Unique, cleaned subdomain list
├── alive_subdomains.txt      # Verified live hosts
├── resolved_ips.txt          # IP addresses of live hosts
├── screenshots/              # PNG screenshots (if a capture tool was used)
│   ├── [www.example.com](https://www.example.com).png
│   └── ...
└── nmap/
    ├── alive_scan.nmap       # Nmap human-readable output
    ├── alive_scan.xml        # XML format (parsable)
    └── alive_scan.gnmap      # Greppable format
```

**File Descriptions:**

- `raw_subdomains.txt`: Unsanitised dump from all enumeration tools.
- `subdomains.txt`: Cleaned, lowercased, deduplicated subdomains (strict regex).
- `alive_subdomains.txt`: Hosts that returned HTTP 200–399.
- `resolved_ips.txt`: IPv4 addresses resolved via socket.
- `screenshots/`: Visual proof of each live web service (full page screenshots).
- `nmap/`: Standard Nmap output files (`-oA`) with service versions.

  
___
## 🔧 Customization

The script is designed to be easy to tweak:

- **HTTP timeout / user-agent:** Edit the embedded Python inside the `check_alive` and `run_nmap` functions.
- **Fallback behaviour:** If you want to force the script to exit when a preferred tool is missing, remove the `|| true` guards.
- **Nmap flags:** Modify the `nmap` command in `run_nmap()` – e.g., add `-p 80,443,8080` for a faster scan.
- **Extra enumeration tools:** Simply add a new `if command -v <tool>` block in `find_subdomains()`.

The whole script is around 150 lines, deliberately kept small so you can audit and modify it quickly.

---

## 📸 Example Run

```bash
$ ./subdomain_audit.sh example.com

==================================================
  Subdomain audit for: example.com
  Output directory: ./subdomain_audit_example_com
==================================================

[1/4] Discovering subdomains...
Discovered 47 unique entries.
[2/4] Checking which subdomains are alive...
Alive hosts:
blog.example.com
[www.example.com](https://www.example.com)
mail.example.com
[3/4] Taking screenshots of alive subdomains...
Screenshots saved in ./subdomain_audit_example_com/screenshots
[4/4] Resolving alive subdomains to IP addresses and running Nmap...
Nmap output written to ./subdomain_audit_example_com/nmap/alive_scan.*

Done. Results are in ./subdomain_audit_example_com

```
___
## ⚠️ Ethical Use & Disclaimer

This tool is intended for **authorised security testing and educational purposes only**.
Always obtain explicit permission before scanning any domain that you do not own or have written consent to test.
Unauthorised scanning may violate local laws and terms of service.

The authors assume no liability for misuse or damage caused by this tool.

---

## 🙏 Acknowledgements

This script integrates industry-standard open-source tools. Huge thanks to their creators:

- [ProjectDiscovery – Subfinder](https://github.com/projectdiscovery/subfinder)
- [TomNomNom – Assetfinder](https://github.com/tomnomnom/assetfinder)
- [OWASP – Amass](https://github.com/owasp-amass/amass)
- [Findomain](https://github.com/Findomain/Findomain)
- [SensePost – GoWitness](https://github.com/sensepost/gowitness)
- [Nmap](https://nmap.org/)
- The Bash and Python communities for making glue scripting possible.

---

## 🤝 Contributing

Pull requests, feature suggestions, and bug reports are welcome!
Please open an issue to discuss major changes before submitting a PR.

---

## 📄 License

This project is licensed under the MIT License – see the [LICENSE](LICENSE) file for details.
