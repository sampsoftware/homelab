#!/usr/bin/env bash
# Power the T620 back on remotely via iDRAC (IPMI over LAN). The host sits in soft-off (S5) after
# lab-shutdown.sh; iDRAC runs on aux power as long as the PSU has AC, so it can always power it on.
# Once the host POSTs, ESXi boots and host autostart restores the guests (vCenter -> gw-vcf ->
# appliance — see shutdown-and-recovery.md). Nothing else to do here.
#
# Requires: ipmitool; network reach to the iDRAC NIC; iDRAC creds. Reads IDRAC_HOST / IDRAC_USER /
# IDRAC_PASS from an env file (default /run/secrets/codedev/homelab.env). MUST run on an always-on
# machine that is NOT a VM on this host. Set DRYRUN=1 to log without acting.
#
# Alternatives if you prefer: Dell racadm  ->  racadm -r $IDRAC_HOST -u .. -p .. serveraction powerup
#                             Redfish      ->  POST .../Systems/System.Embedded.1/Actions/ComputerSystem.Reset {"ResetType":"On"}
set -uo pipefail

LAB_ENV="${LAB_ENV:-/run/secrets/codedev/homelab.env}"
DRYRUN="${DRYRUN:-0}"
log() { echo "[$(date -u +%FT%TZ)] $*"; }
die() { log "FATAL: $*"; exit 1; }

[ -r "$LAB_ENV" ] || die "env file not readable: $LAB_ENV"
set -a; . "$LAB_ENV"; set +a
strip() { printf '%s' "${1:-}" | tr -d '\r\n'; }
H="$(strip "${IDRAC_HOST:-}")"; U="$(strip "${IDRAC_USER:-}")"; P="$(strip "${IDRAC_PASS:-}")"
[ -n "$H$U$P" ] || die "IDRAC_HOST/IDRAC_USER/IDRAC_PASS not set in $LAB_ENV"
command -v ipmitool >/dev/null || die "ipmitool not on PATH (apt-get install ipmitool)"

IPMI=(ipmitool -I lanplus -H "$H" -U "$U" -P "$P")
status="$("${IPMI[@]}" chassis power status 2>&1)" || die "cannot reach iDRAC $H: $status"
log "iDRAC $H reports: $status"
if echo "$status" | grep -qi "on$"; then log "host already powered on — nothing to do"; exit 0; fi

if [ "$DRYRUN" = "1" ]; then log "DRYRUN> ${IPMI[*]/$P/****} chassis power on"; exit 0; fi
log "powering on..."
"${IPMI[@]}" chassis power on && log "power-on command accepted; host will POST then ESXi autostart restores VMs."
