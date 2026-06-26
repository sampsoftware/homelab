#!/usr/bin/env bash
# Gracefully shut down the whole lab (guests in order) and power off the ESXi host.
#
# Drives the ESXi host DIRECTLY (not vCenter) — because this script also shuts vCenter down, it
# must not depend on vCenter being up. Order: tanzu-platform-appliance -> gw-vcf -> vcenter-vcf
# (most-stateful first, so each gets its full flush window while the rest are still up), then the
# host is powered off (soft off / S5 — iDRAC stays alive on aux power so it can be powered back on).
#
# Requires: govc on PATH; direct network reach to the ESXi host's mgmt IP; ESxi creds. Reads them
# from an env file (default /run/secrets/codedev/homelab.env): ESXI_USER / ESXI_PASSWORD, and
# optionally ESXI_IP (the host's direct IP; defaults to trying 192.168.20.13 then .10). It does NOT
# use ESXI_URL — that name is gw-vcf's proxy, which this script shuts down. See shutdown-and-recovery.md.
#
# MUST run on an always-on machine that is NOT a VM on this host (gw-vcf etc. die with the host).
# Set DRYRUN=1 to log actions without touching anything. See shutdown-and-recovery.md.
set -uo pipefail

LAB_ENV="${LAB_ENV:-/run/secrets/codedev/homelab.env}"
DRYRUN="${DRYRUN:-0}"
# Per-VM grace before a forced power-off (seconds). Appliance gets the most (Docker/BOSH/PG/CH).
ORDER=( "tanzu-platform-appliance:300" "gw-vcf:90" "vcenter-vcf:180" )

log() { echo "[$(date -u +%FT%TZ)] $*"; }
die() { log "FATAL: $*"; exit 1; }

# --- load creds (tolerate CRLF in the env file) ---
[ -r "$LAB_ENV" ] || die "env file not readable: $LAB_ENV"
set -a; . "$LAB_ENV"; set +a
strip() { printf '%s' "${1:-}" | tr -d '\r\n'; }
export GOVC_USERNAME="$(strip "${ESXI_USER:-}")"
export GOVC_PASSWORD="$(strip "${ESXI_PASSWORD:-}")"
export GOVC_INSECURE=1

run() { if [ "$DRYRUN" = "1" ]; then log "DRYRUN> $*"; else "$@"; fi; }
powerstate() { govc vm.info -json "$1" 2>/dev/null | jq -r '.virtualMachines[0].runtime.powerState // "unknown"'; }

# --- preflight ---
command -v govc >/dev/null || die "govc not on PATH"
command -v jq   >/dev/null || die "jq not on PATH"

# Connect to the ESXi host by DIRECT IP, never the proxied name. ESXI_URL in homelab.env is
# esxi-t620.vcf.sampsoftware.net, which resolves to gw-vcf's Traefik (.5) — but this script SHUTS
# gw-vcf DOWN, so using that name severs our own control path before we can power off the host
# (the same gateway-inception trap that applies to the iDRAC). Try the host's direct mgmt IPs.
ESXI_IPS="${ESXI_IP:-192.168.20.13 192.168.20.10}"
GOVC_URL=""; export GOVC_URL
for ip in $ESXI_IPS; do
  export GOVC_URL="https://$ip"
  about=$(govc about 2>&1) && { log "connected directly to ESXi at $ip: $(echo "$about" | awk -F'  +' '/FullName/{print $2}')"; break; }
  GOVC_URL=""
done
[ -n "$GOVC_URL" ] || die "cannot reach ESXi host directly (tried: $ESXI_IPS)"
HOST=$(govc find -type h 2>/dev/null | head -1)
[ -n "$HOST" ] || die "could not resolve ESXi host object"
log "host object: $HOST  (DRYRUN=$DRYRUN)"

# --- shut down each guest gracefully, force-off if it overstays its grace window ---
for entry in "${ORDER[@]}"; do
  vm="${entry%%:*}"; grace="${entry##*:}"
  st="$(powerstate "$vm")"
  if [ "$st" != "poweredOn" ]; then log "$vm: already $st — skip"; continue; fi
  log "$vm: guest shutdown (up to ${grace}s for clean flush)"
  run govc vm.power -s "$vm"
  if [ "$DRYRUN" = "1" ]; then continue; fi
  waited=0
  while [ "$waited" -lt "$grace" ]; do
    sleep 10; waited=$((waited+10))
    [ "$(powerstate "$vm")" = "poweredOff" ] && { log "$vm: powered off after ${waited}s"; break; }
  done
  if [ "$(powerstate "$vm")" != "poweredOff" ]; then
    log "$vm: still up after ${grace}s — forcing power off"
    govc vm.power -off -force "$vm" || log "WARN: force-off of $vm failed"
    sleep 5
  fi
done

# --- power off the host (soft off; iDRAC remains available to power it back on) ---
log "all guests down — powering off host $HOST"
run govc host.shutdown -f "$HOST"
log "host power-off issued. Done."
