# Certificate plan

How TLS certs work across the lab. Two namespaces, two realities:

1. **Public-rooted names** (`*.sampsoftware.net` and children) — we own `sampsoftware.net`
   and it's on Cloudflare DNS, so a public CA can issue. **Let's Encrypt issues, Cloudflare
   validates** (DNS-01). This is the only path that yields browser-trusted certs.
2. **`tanzu.lab`** (the appliance's original private domain) — `.lab` is not a real TLD, so
   **no public CA can ever issue** for it. We avoid this entirely by re-domaining the appliance
   under the public zone (below).

> **Cloudflare vs Let's Encrypt isn't a fork — they're different layers.** Let's Encrypt is the
> CA; Cloudflare is the DNS operator answering the ACME DNS-01 challenge (`--dns-cloudflare`).
> Every public cert here uses *both*. Cloudflare's own Origin CA / Tunnel only matters for
> proxying traffic through Cloudflare's edge, which this LAN-only lab does not do.

## Scope: LAN-only

Everything is reachable only from inside VLAN 20 / the home network. We still use a public CA
(so certs are trusted with zero client config), but we publish **no public A records** — names
resolve to internal IPs via split-horizon DNS on the lab resolver. DNS-01 validation only needs
`_acme-challenge` TXT records, which the certbot Cloudflare plugin creates and removes itself.

## The appliance: re-domained under the public zone

`config.json` was moved off `tanzu.lab` onto `tpcf.lab.sampsoftware.net`:

| field | value |
|---|---|
| `domain` | `tpcf.lab.sampsoftware.net` |
| `sys_domain` | `sys.tpcf.lab.sampsoftware.net` |
| `apps_domain` | `apps.tpcf.lab.sampsoftware.net` |
| `tpcf_domain` | `tpcf.lab.sampsoftware.net` |

Endpoints become `hub.tpcf…`, `ops.tpcf…`, `api.sys.tpcf…`, apps on `*.apps.tpcf…`.

### Cert (one dedicated appliance cert)

Issued by `issue-appliance-cert.sh` (run on the bastion). A wildcard matches exactly one
label, so `sys.*` and `apps.*` each need their own SAN:

```
tpcf.lab.sampsoftware.net
*.tpcf.lab.sampsoftware.net          # hub, ops
*.sys.tpcf.lab.sampsoftware.net      # api, login, uaa, apps manager
*.apps.tpcf.lab.sampsoftware.net     # deployed apps
```

Kept separate from the lab-infra cert (`*.lab.sampsoftware.net`) so a renewal/validation
hiccup on one doesn't take down the other, and only the appliance cert ever leaves the bastion.

### LAN DNS (split-horizon)

On the lab resolver (UniFi / PiHole dnsmasq), one line covers the whole tree — dnsmasq's
`address=/domain/ip` matches the domain *and all* subdomains:

```
address=/tpcf.lab.sampsoftware.net/192.168.20.12
```

This is only for workstations/clients. The appliance keeps its **own** internal dnsmasq
(`wildcard-dns.service`) for container-to-container resolution; don't conflate the two.

### Injecting the cert into the appliance

The appliance has **no OVF property for a custom cert** — `ovf-firstboot.sh` self-generates a
Traefik cert from the domain SANs. Traefik (the single ingress) mounts
`/opt/traefik/certs → /certs:ro`, so that directory is the injection point.

`deploy-cert-to-appliance.sh` copies `fullchain.pem`/`privkey.pem` into `/opt/traefik/certs/`
and restarts Traefik. It runs as a certbot `--deploy-hook`, so **renewals auto-push** — and
certbot's own systemd timer drives the 90-day renewal. Run once manually for the first issue.

**Confirm the target filenames once** on the running appliance and set `CERT_CRT`/`CERT_KEY`
in the deploy script to match:

```bash
grep -rEi 'certFile|keyFile|certificates' /opt/traefik/config
```

### What stays self-signed (and that's fine)

The appliance is built assuming self-signed — `configure-cf-apps-manager.sh` sets
`SKIP_SSL_VALIDATION=true` for Apps Manager. Replacing Traefik's **edge** cert gives trusted
browser access to Hub/Ops/Apps Manager and trusted `cf login` (no `--skip-ssl-validation`).
The platform's **internal** BOSH/GoRouter certs keep their own self-signed CA — normal for a
foundation, not worth chasing in a lab.

## Lab-infra names (`*.lab.sampsoftware.net`)

Same mechanism, separate cert: Let's Encrypt + Cloudflare DNS-01 for `vcenter.lab…`,
`esxi-t620.lab…`, `hub.lab…`, etc. The legacy `certbot.sh` bundled infra + TAS names into one
oversized cert with inconsistent naming (`tpcf.sampsoftware.net` vs `tpcf.lab.sampsoftware.net`,
`tas.sampsoftware.net`); when you revisit it, split it to `*.lab.sampsoftware.net` (+ apex) and
drop the appliance names (now covered by the dedicated cert above).

## ⚠️ Cloudflare token

`secrets/cf.ini` is committed to git history (see `CLAUDE.md`). **Rotate it:**

1. Cloudflare dashboard → create an API token scoped to **Zone → DNS → Edit**, on
   **`sampsoftware.net` only** (not the global key).
2. Store it **outside the repo** — `~/.secrets/cf.ini` on the bastion (the default
   `CF_INI` in `issue-appliance-cert.sh`), mode `0600`, format:
   ```
   dns_cloudflare_api_token = <token>
   ```
3. Remove the tracked `secrets/cf.ini`; the old token is in history, so rotation (step 1) is
   what actually neutralizes it.

## Runbook (first issue)

```bash
# on the bastion, with ~/.secrets/cf.ini in place and ~/.ssh/id_opsman able to reach the appliance
./issue-appliance-cert.sh                 # issues + runs the deploy hook
# confirm Traefik picked it up:
curl -v https://hub.tpcf.lab.sampsoftware.net 2>&1 | grep -Ei 'issuer|subject|verify'
```

Renewals are automatic (certbot timer → deploy hook). Add the dnsmasq line to the lab resolver
once; it doesn't change on renewal.
