#!/usr/bin/env bash
# Power the T620 back on remotely via the iDRAC Redfish API (HTTPS). The host sits in soft-off (S5)
# after lab-shutdown.sh; the iDRAC runs on aux power as long as the PSU has AC, so it can always
# power the host on. Once it POSTs, ESXi boots and host autostart restores the guests (vCenter ->
# gw-vcf -> appliance — see shutdown-and-recovery.md). Nothing else to do here.
#
# Uses Redfish over 443 (not IPMI): on this iDRAC, IPMI-over-LAN (udp/623) is disabled, while Redfish
# is enabled and needs no ipmitool. Reads IDRAC_HOST / IDRAC_USER / IDRAC_PASS from an env file
# (default /run/secrets/codedev/homelab.env); IDRAC_HOST defaults to the confirmed iDRAC 192.168.20.9.
# MUST run on an always-on machine that is NOT a VM on this host. Set DRYRUN=1 to log without acting.
#
# ipmitool alternative (only if you enable IPMI-over-LAN in the iDRAC network settings):
#   ipmitool -I lanplus -H $IDRAC_HOST -U $IDRAC_USER -P $IDRAC_PASS chassis power on
set -uo pipefail

LAB_ENV="${LAB_ENV:-/run/secrets/codedev/homelab.env}"
DRYRUN="${DRYRUN:-0}"
log() { echo "[$(date -u +%FT%TZ)] $*"; }
die() { log "FATAL: $*"; exit 1; }

[ -r "$LAB_ENV" ] || die "env file not readable: $LAB_ENV"
set -a; . "$LAB_ENV"; set +a
strip() { printf '%s' "${1:-}" | tr -d '\r\n'; }
H="$(strip "${IDRAC_HOST:-192.168.20.9}")"
U="$(strip "${IDRAC_USER:-}")"
P="$(strip "${IDRAC_PASS:-}")"
[ -n "$U" ] && [ -n "$P" ] || die "IDRAC_USER/IDRAC_PASS not set in $LAB_ENV"
command -v curl >/dev/null || die "curl not on PATH"

SYS="https://$H/redfish/v1/Systems/System.Embedded.1"
rf() { curl -sk --max-time 15 -u "$U:$P" "$@"; }

# current power state (also validates creds/reachability)
body="$(rf "$SYS" 2>&1)" || die "cannot reach iDRAC $H Redfish: $body"
state="$(printf '%s' "$body" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("PowerState","?"))' 2>/dev/null || echo '?')"
log "iDRAC $H reports PowerState=$state"
case "$state" in
  On)  log "host already on — nothing to do"; exit 0 ;;
  Off) : ;;
  *)   log "WARN: unexpected/auth-failed PowerState ('$state'); check creds. Body: $(printf '%s' "$body" | head -c 200)" ;;
esac

RESET="$SYS/Actions/ComputerSystem.Reset"
if [ "$DRYRUN" = "1" ]; then log "DRYRUN> POST $RESET {\"ResetType\":\"On\"}"; exit 0; fi
log "powering on via Redfish..."
code="$(rf -o /dev/null -w '%{http_code}' -H 'Content-Type: application/json' -X POST "$RESET" -d '{"ResetType":"On"}')"
case "$code" in
  20*) log "power-on accepted (HTTP $code); host will POST, then ESXi autostart restores VMs." ;;
  *)   die "power-on POST failed (HTTP $code)" ;;
esac
