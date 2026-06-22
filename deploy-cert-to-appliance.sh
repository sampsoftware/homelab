#!/bin/bash
# Push the Let's Encrypt appliance cert into the Tanzu Platform appliance's Traefik and reload.
#
# Usable two ways:
#   - As a certbot --deploy-hook: certbot exports $RENEWED_LINEAGE (the live cert dir).
#   - Manually: pass the live dir as $1, e.g.
#       ./deploy-cert-to-appliance.sh /etc/letsencrypt/live/tpcf-appliance
#
# Traefik (the appliance's single ingress) mounts /opt/traefik/certs -> /certs:ro
# (traefik.service). We drop fullchain.pem + privkey.pem there under the names Traefik's
# TLS config references, then restart Traefik.
#
# IMPORTANT: confirm the expected filenames once, on the running appliance:
#   grep -rEi 'certFile|keyFile|certificates' /opt/traefik/config
# and set CERT_CRT / CERT_KEY below to match. Defaults are the common appliance names.
set -euo pipefail

LINEAGE="${1:-${RENEWED_LINEAGE:-/etc/letsencrypt/live/tpcf-appliance}}"

# Appliance access. After the re-domain the host is the appliance IP (DNS may not be live yet
# during first issuance), with the opsman key. vcap has passwordless sudo on the appliance.
APPLIANCE_HOST="${APPLIANCE_HOST:-192.168.20.12}"
APPLIANCE_USER="${APPLIANCE_USER:-vcap}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_opsman}"

# Target filenames inside /opt/traefik/certs (confirm — see note above).
CERT_DIR="/opt/traefik/certs"
CERT_CRT="${CERT_CRT:-tls.crt}"
CERT_KEY="${CERT_KEY:-tls.key}"

SSH=(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new "${APPLIANCE_USER}@${APPLIANCE_HOST}")
SCP=(scp -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new)

echo "Deploying $LINEAGE -> ${APPLIANCE_USER}@${APPLIANCE_HOST}:${CERT_DIR}/{$CERT_CRT,$CERT_KEY}"

# Stage to a temp dir on the appliance, then move into place with sudo.
TMP="/tmp/tpcf-cert.$$"
"${SSH[@]}" "mkdir -p $TMP"
"${SCP[@]}" "$LINEAGE/fullchain.pem" "${APPLIANCE_USER}@${APPLIANCE_HOST}:$TMP/$CERT_CRT"
"${SCP[@]}" "$LINEAGE/privkey.pem"   "${APPLIANCE_USER}@${APPLIANCE_HOST}:$TMP/$CERT_KEY"

"${SSH[@]}" "sudo install -o root -g root -m 0644 $TMP/$CERT_CRT $CERT_DIR/$CERT_CRT && \
             sudo install -o root -g root -m 0600 $TMP/$CERT_KEY $CERT_DIR/$CERT_KEY && \
             rm -rf $TMP && \
             sudo systemctl restart traefik.service && \
             echo 'Traefik restarted with new cert.'"

echo "Done."
