#!/usr/bin/env bash

set -euo pipefail

DOMAIN="${1:-}"
if [[ -z "$DOMAIN" ]]; then
  echo "Usage: $0 <domain>"
  echo "Example: $0 example.com"
  exit 1
fi

WORK_DIR="./subdomain_audit_${DOMAIN//[^A-Za-z0-9]/_}"
mkdir -p "$WORK_DIR"

RAW_SUBDOMAINS="$WORK_DIR/raw_subdomains.txt"
UNIQUE_SUBDOMAINS="$WORK_DIR/subdomains.txt"
ALIVE_SUBDOMAINS="$WORK_DIR/alive_subdomains.txt"
RESOLVED_IPS="$WORK_DIR/resolved_ips.txt"
SCREENSHOT_DIR="$WORK_DIR/screenshots"
NMAP_DIR="$WORK_DIR/nmap"

mkdir -p "$SCREENSHOT_DIR" "$NMAP_DIR"
: > "$RAW_SUBDOMAINS"

banner() {
  echo
  echo "=================================================="
  echo "  Subdomain audit for: $DOMAIN"
  echo "  Output directory: $WORK_DIR"
  echo "=================================================="
  echo
}

find_subdomains() {
  echo "[1/4] Discovering subdomains..."

  if command -v subfinder >/dev/null 2>&1; then
    subfinder -d "$DOMAIN" -silent -all 2>/dev/null >> "$RAW_SUBDOMAINS" || true
  fi

  if command -v assetfinder >/dev/null 2>&1; then
    assetfinder --subs-only "$DOMAIN" 2>/dev/null >> "$RAW_SUBDOMAINS" || true
  fi

  if command -v amass >/dev/null 2>&1; then
    amass enum -passive -d "$DOMAIN" 2>/dev/null >> "$RAW_SUBDOMAINS" || true
  fi

  if command -v findomain >/dev/null 2>&1; then
    findomain -t "$DOMAIN" -q 2>/dev/null >> "$RAW_SUBDOMAINS" || true
  fi

  # fallback: use the root domain itself as a basic target
  echo "$DOMAIN" >> "$RAW_SUBDOMAINS"

  # Simple and reliable unique-domain extraction using shell tools.
  grep -E '^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' "$RAW_SUBDOMAINS" \
    | sed 's#^https\?://##; s#/$##' \
    | sort -u > "$UNIQUE_SUBDOMAINS"

  echo "Discovered $(wc -l < "$UNIQUE_SUBDOMAINS") unique entries."
}

check_alive() {
  echo "[2/4] Checking which subdomains are alive..."

  python3 - "$UNIQUE_SUBDOMAINS" "$ALIVE_SUBDOMAINS" <<'PY'
import sys
import urllib.request
import urllib.error

infile, outfile = sys.argv[1:3]
results = set()

with open(infile, 'r', encoding='utf-8', errors='ignore') as fh:
    for domain in fh:
        domain = domain.strip().lower()
        if not domain:
            continue
        for scheme in ('https', 'http'):
            url = f"{scheme}://{domain}"
            try:
                req = urllib.request.Request(url, method='GET', headers={'User-Agent': 'subdomain-audit/1.0'})
                with urllib.request.urlopen(req, timeout=10) as resp:
                    code = getattr(resp, 'status', resp.getcode())
                    if 200 <= code < 400:
                        results.add(domain)
                        break
            except Exception:
                continue

with open(outfile, 'w', encoding='utf-8') as fh:
    for domain in sorted(results):
        fh.write(domain + '\n')
PY

  if [[ ! -s "$ALIVE_SUBDOMAINS" ]]; then
    echo "No alive subdomains were found."
    exit 0
  fi

  echo "Alive hosts:"
  cat "$ALIVE_SUBDOMAINS"
}

capture_screenshots() {
  echo "[3/4] Taking screenshots of alive subdomains..."

  if command -v gowitness >/dev/null 2>&1; then
    gowitness file -f "$ALIVE_SUBDOMAINS" -P "$SCREENSHOT_DIR" >/dev/null 2>&1 || true
    echo "Screenshots saved in $SCREENSHOT_DIR"
    return
  fi

  if command -v npx >/dev/null 2>&1 && npx --yes playwright --version >/dev/null 2>&1; then
    while IFS= read -r host; do
      safe_name="${host//[^A-Za-z0-9.-]/_}"
      npx --yes playwright screenshot "https://$host" "$SCREENSHOT_DIR/${safe_name}.png" >/dev/null 2>&1 || \
        npx --yes playwright screenshot "http://$host" "$SCREENSHOT_DIR/${safe_name}.png" >/dev/null 2>&1 || true
    done < "$ALIVE_SUBDOMAINS"
    echo "Screenshots saved in $SCREENSHOT_DIR"
    return
  fi

  echo "No screenshot tool found. Install gowitness or Playwright to capture screenshots."
}

run_nmap() {
  echo "[4/4] Resolving alive subdomains to IP addresses and running Nmap..."

  python3 - "$ALIVE_SUBDOMAINS" "$RESOLVED_IPS" <<'PY'
import socket
import sys

infile, outfile = sys.argv[1:3]
ips = set()
with open(infile, 'r', encoding='utf-8', errors='ignore') as fh:
    for host in fh:
        host = host.strip().lower()
        if not host:
            continue
        try:
            info = socket.gethostbyname_ex(host)
            ips.update(info[2])
        except Exception:
            continue

with open(outfile, 'w', encoding='utf-8') as fh:
    for ip in sorted(ips):
        fh.write(ip + '\n')
PY

  if [[ ! -s "$RESOLVED_IPS" ]]; then
    echo "No IP addresses were resolved for Nmap scanning."
    return
  fi

  if command -v nmap >/dev/null 2>&1; then
    nmap -Pn --open -sV -iL "$RESOLVED_IPS" -oA "$NMAP_DIR/alive_scan" || true
    echo "Nmap output written to $NMAP_DIR/alive_scan.*"
  else
    echo "Nmap is not installed. Install Nmap to scan the live hosts."
  fi
}

banner
find_subdomains
check_alive
capture_screenshots
run_nmap

echo
echo "Done. Results are in $WORK_DIR"
