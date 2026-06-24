#!/bin/bash
# certbot --deploy-hook: push the renewed LE cert into the new vCenter's Machine SSL
# store via the vSphere REST cert-management API. Runs on first issue and every renewal.
# Replacing the Machine SSL cert restarts all vCenter services (~10-15 min).
set -euo pipefail

VC="vcenter.vcf.sampsoftware.net"
LINEAGE="${RENEWED_LINEAGE:-/etc/letsencrypt/live/vcenter-vcf}"
read -r VC_USER VC_PASS < /root/.secrets/vcenter.cred

echo "[push] $(date -u +%FT%TZ) acquiring session on $VC"
TOKEN=$(curl -sk -u "$VC_USER:$VC_PASS" -X POST "https://$VC/api/session")
TOKEN="${TOKEN//\"/}"
[ -n "$TOKEN" ] || { echo "[push] ERROR: no session token"; exit 1; }

echo "[push] replacing Machine SSL cert (vCenter will restart services)"
# root_cert must terminate in a self-signed root. LE's chain.pem stops at an
# intermediate ("Root YR"), so append the actual self-signed ISRG Root X1 or
# vCenter rejects it ("trustAnchors must be non-empty").
ROOTCHAIN=/tmp/vc-rootchain.pem
cat "$LINEAGE/chain.pem" /etc/ssl/certs/ISRG_Root_X1.pem > "$ROOTCHAIN"
BODY=$(jq -n \
  --rawfile cert "$LINEAGE/cert.pem" \
  --rawfile key  "$LINEAGE/privkey.pem" \
  --rawfile root "$ROOTCHAIN" \
  '{cert:$cert, key:$key, root_cert:$root}')

code=$(curl -sk --max-time 120 -o /tmp/vc-cert-resp.json -w '%{http_code}' \
  -X PUT "https://$VC/api/vcenter/certificate-management/vcenter/tls" \
  -H "vmware-api-session-id: $TOKEN" -H 'Content-Type: application/json' \
  -d "$BODY" || true)
echo "[push] PUT http=$code resp=$(head -c 300 /tmp/vc-cert-resp.json 2>/dev/null)"

echo "[push] waiting for vCenter to come back up..."
for i in $(seq 1 80); do
  if curl -sk --max-time 5 "https://$VC/api/appliance/health/system" >/dev/null 2>&1; then
    echo "[push] vCenter healthy again after ~$((i*15))s"; exit 0
  fi
  sleep 15
done
echo "[push] WARNING: vCenter not confirmed healthy within timeout (it may still be restarting)"
