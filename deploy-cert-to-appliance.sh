#!/bin/bash
# Push the Let's Encrypt appliance cert into the Tanzu Platform appliance's Traefik and reload.
#
# Usable two ways:
#   - As a certbot --deploy-hook: certbot exports $RENEWED_LINEAGE (the live cert dir).
#   - Manually: pass the live dir as $1, e.g.
#       ./deploy-cert-to-appliance.sh /etc/letsencrypt/live/tanzu-appliance
#
# On gw-vcf this is installed as /usr/local/bin/push-cert-to-appliance.sh and wired as the
# renew_hook in /etc/letsencrypt/renewal/tanzu-appliance.conf (keep the two in sync).
#
# The appliance's single ingress Traefik loads /opt/traefik/certs/apps-fullchain.pem +
# apps-key.pem (per /opt/traefik/config/dynamic/tls.yml). We drop the LE fullchain + key there
# under exactly those names, then restart Traefik.
#
# ⚠️ This only changes what the EDGE serves. The internal `frpc` stitching agent pins the
#    appliance CA bundle, so for a publicly-trusted cert you must ALSO add the LE root (ISRG Root
#    X1) to the hub-tas-collector tile property `.properties.hub_ca_certificate` (one-time) — else
#    the Platform Services tile silently fails to deploy. Renewals are safe once that's done (a
#    renewed LE cert still chains to ISRG Root X1). Full procedure:
#    ../tpa-homelab/tanzu-platform-appliance.md → "Custom edge certificate (and the frpc trust trap)".
set -euo pipefail

LINEAGE="${1:-${RENEWED_LINEAGE:-/etc/letsencrypt/live/tanzu-appliance}}"

# Appliance access. The host is the appliance IP (DNS may not be live during first issuance),
# with the appliance SSH key. vcap has passwordless sudo on the appliance.
APPLIANCE_HOST="${APPLIANCE_HOST:-192.168.20.12}"
APPLIANCE_USER="${APPLIANCE_USER:-vcap}"
SSH_KEY="${SSH_KEY:-/root/.secrets/id_appliance}"

# Target filenames inside /opt/traefik/certs — these are what tls.yml references; do not rename.
CERT_DIR="/opt/traefik/certs"
CERT_CRT="${CERT_CRT:-apps-fullchain.pem}"
CERT_KEY="${CERT_KEY:-apps-key.pem}"

O=(-i "$SSH_KEY" -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null)

echo "[push] $(date -u +%FT%TZ) deploying $LINEAGE -> ${APPLIANCE_USER}@${APPLIANCE_HOST}:${CERT_DIR}/{$CERT_CRT,$CERT_KEY}"

# Stage to a temp dir on the appliance, then install into place with sudo (0600, root-owned).
TMP="/tmp/appl-cert.$$"
ssh "${O[@]}" "${APPLIANCE_USER}@${APPLIANCE_HOST}" "mkdir -p $TMP"
scp "${O[@]}" "$LINEAGE/fullchain.pem" "${APPLIANCE_USER}@${APPLIANCE_HOST}:$TMP/$CERT_CRT"
scp "${O[@]}" "$LINEAGE/privkey.pem"   "${APPLIANCE_USER}@${APPLIANCE_HOST}:$TMP/$CERT_KEY"
ssh "${O[@]}" "${APPLIANCE_USER}@${APPLIANCE_HOST}" \
    "sudo install -o root -g root -m0600 $TMP/$CERT_CRT $CERT_DIR/$CERT_CRT && \
     sudo install -o root -g root -m0600 $TMP/$CERT_KEY $CERT_DIR/$CERT_KEY && \
     rm -rf $TMP && sudo systemctl restart traefik.service && \
     echo '[push] appliance traefik restarted with LE cert'"

echo "[push] done."
