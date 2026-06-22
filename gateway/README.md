# gateway — Traefik reverse proxy for VMware infra UIs

A small Linux VM (`gw.vcf.sampsoftware.net`) runs **Traefik v3** with built-in
**ACME (Let's Encrypt via Cloudflare DNS-01)** and reverse-proxies the VMware
infrastructure management UIs (vCenter, ESXi) so they present **trusted,
auto-renewing** certs in the browser instead of their self-signed ones.

Traefik terminates a trusted wildcard cert for `*.vcf.sampsoftware.net` and
forwards to the backends over HTTPS, skipping verification of their
self-signed certs (`insecure-backend` serversTransport).

| Hostname                            | Backend                | Purpose      |
|-------------------------------------|------------------------|--------------|
| `vcenter.vcf.sampsoftware.net`      | `https://192.168.20.11`| vCenter H5 UI / SDK |
| `esxi-t620.vcf.sampsoftware.net`    | `https://192.168.20.13`| ESXi host UI |

## Setup runbook

### 1. Build the gateway VM
Build a minimal Ubuntu/Debian VM on the T620, named `gw.vcf.sampsoftware.net`,
with a **static IP on the VLAN-20 portgroup** (e.g. `192.168.20.5` — pick a
free VLAN-20 IP). Install **Docker Engine + the compose plugin**:

```bash
curl -fsSL https://get.docker.com | sh
```

### 2. Create the `.env` file
Next to this compose file, create `.env` with a Cloudflare API token scoped
**Zone:DNS:Edit** on `sampsoftware.net`:

```bash
echo 'CF_DNS_API_TOKEN=<token>' > .env
chmod 600 .env
```

`.env` is gitignored — **never commit it**.

### 3. Add split-horizon LAN DNS
On the UDM, add LAN DNS **A records** pointing the proxied hostnames at the
**gateway VM's IP** (NOT the host IPs — pointing them at the gateway is what
routes the traffic through the proxy):

```
vcenter.vcf.sampsoftware.net    -> <gateway VM IP>
esxi-t620.vcf.sampsoftware.net  -> <gateway VM IP>
```

### 4. Start Traefik

```bash
docker compose up -d
```

On first start Traefik runs the DNS-01 challenge through Cloudflare and writes
the wildcard cert to the `traefik_acme` volume (`/acme/acme.json`).

### 5. Verify

```bash
curl -v https://vcenter.vcf.sampsoftware.net 2>&1 | grep -i issuer
```

You should see a Let's Encrypt issuer (`C=US, O=Let's Encrypt, ...`).

## Notes

- **Scope:** this proxies the **web UIs + SDK over 443** → trusted for browsers
  and `govc`. **VM consoles (WebMKS) and OVF/datastore file transfers use port
  902 / connect direct-to-host and still hit the host's self-signed cert** —
  that's expected and not something this gateway covers. (Traefik passes
  WebSockets through automatically, so the in-page HTML5 console over 443 works
  without extra config.)
- **Tanzu is NOT proxied here.** The Tanzu appliance
  (`*.tanzu.vcf.sampsoftware.net`) runs its own Traefik. This gateway is only
  for the bare-metal infra hosts (vCenter, ESXi).
- **No CSP / strict security-headers middleware** is applied to these routers —
  the vCenter/ESXi H5 UIs break under a tight CSP. Only `local-network-only`
  (IP allowlist) is applied.
- **Intermittent uptime is fine.** The T620 powers off for extended periods.
  ACME only needs the gateway up *sometime within* each cert's ~90-day window
  to renew, so periodic downtime does not break renewal.
