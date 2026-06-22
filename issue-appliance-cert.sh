#!/bin/bash
# Issue the Let's Encrypt wildcard cert for the Tanzu Platform appliance, validated via
# Cloudflare DNS-01. LAN-only: no public A records are needed — DNS-01 only writes
# _acme-challenge TXT records in the sampsoftware.net Cloudflare zone.
#
# Run on the lab bastion (has certbot + the dns-cloudflare plugin). See certs.md for the
# full scheme, the Cloudflare token scope, and the DNS / injection steps.
#
# A wildcard matches exactly one label, so sys.* and apps.* each need their own SAN.
set -euo pipefail

# Cloudflare API token file (Zone:DNS:Edit on sampsoftware.net ONLY).
# Do NOT commit this — keep it out of the repo (see certs.md "Cloudflare token").
CF_INI="${CF_INI:-$HOME/.secrets/cf.ini}"

# certbot lineage name — keeps this cert separate from the lab-infra cert.
CERT_NAME="${CERT_NAME:-tanzu-appliance}"

# Deploy hook: push the (re)issued cert into the appliance and reload Traefik.
# certbot runs this on issue and on every renewal. Set DEPLOY_HOOK= to skip.
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_HOOK="${DEPLOY_HOOK:-$HOOK_DIR/deploy-cert-to-appliance.sh}"

sudo certbot certonly \
    --dns-cloudflare \
    --dns-cloudflare-credentials "$CF_INI" \
    --dns-cloudflare-propagation-seconds 20 \
    --cert-name "$CERT_NAME" \
    --key-type rsa \
    ${DEPLOY_HOOK:+--deploy-hook "$DEPLOY_HOOK"} \
    -d "tanzu.vcf.sampsoftware.net" \
    -d "*.tanzu.vcf.sampsoftware.net" \
    -d "*.sys.tanzu.vcf.sampsoftware.net" \
    -d "*.apps.tanzu.vcf.sampsoftware.net"

echo
echo "Issued. Live cert: /etc/letsencrypt/live/$CERT_NAME/"
echo "Renewals run via certbot's systemd timer; the deploy hook re-pushes to the appliance."
