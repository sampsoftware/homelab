#!/bin/bash
sudo certbot certonly \
    --dns-cloudflare \
    --dns-cloudflare-credentials secrets/cf.ini \
    --key-type rsa \
    --dns-cloudflare-propagation-seconds 20 \
    -d "sampsoftware.net" \
    -d "*.sampsoftware.net" \
    -d "*.lab.sampsoftware.net" \
    -d "*.tanzu.vcf.sampsoftware.net" \
    -d "apps.tas.sampsoftware.net" \
    -d "*.apps.tpcf.sampsoftware.net" \
    -d "system.tpcf.sampsoftware.net" \
    -d "*.system.tpcf.sampsoftware.net"

