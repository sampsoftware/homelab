# Certificate plan

Trusted, auto-renewing TLS across the VMware lab, driven from one host (`gw-vcf`) and one
Cloudflare token, with **nothing co-located with the personal `sampstack` project**. Naming
follows [`naming.md`](naming.md) (the `vcf` substrate).

> **LE vs Cloudflare aren't a fork — they're layers.** Let's Encrypt is the CA; Cloudflare is the
> DNS operator answering the ACME DNS-01 challenge. Everything here uses both. DNS-01 needs only
> outbound API access + `_acme-challenge` TXT records, so it works **LAN-only** with no public A
> records, even while the host is powered off between renewals.

## Three consumers, two techniques

Everything runs on the **`gw-vcf`** gateway VM (`192.168.20.5`): Traefik for the proxy case,
certbot (+ deploy-hooks) for the push cases. One token (`CF_DNS_API_TOKEN`).

| Target | Technique | Why |
|---|---|---|
| **vCenter** `vcenter.vcf.sampsoftware.net` | LE cert **pushed onto vCenter's Machine SSL** (certbot → vSphere REST API) | A proxy can't front vCenter — SSO/SAML binds to the PNID, so you *must* hit the real name with a real cert. |
| **ESXi** `esxi-t620.vcf.sampsoftware.net` | Gateway **reverse-proxy** (Traefik) | ESXi has no SSO; proxying the UI/API is clean and needs zero host changes. |
| **Tanzu appliance** `*.tanzu.vcf…` | LE wildcard **pushed into the appliance's own Traefik** | The appliance already runs Traefik; double-proxying buys nothing. |

## vCenter — cert pushed to Machine SSL (auto-renewing)

`vcenter.vcf.sampsoftware.net` is vCenter's PNID, so it carries a real LE cert *on the appliance*:

- certbot on `gw-vcf` holds the `vcenter-vcf` lineage (DNS-01, RSA), with **`push-cert-to-vcenter.sh`**
  as the `--deploy-hook` (saved as `renew_hook` in the renewal config).
- The hook `PUT`s the cert to `…/api/vcenter/certificate-management/vcenter/tls`. vCenter applies it
  and blips its services (~seconds–minutes), then the hook waits for health.
- `certbot.timer` (twice-daily) re-issues + re-pushes automatically — **no manual quarterly dance.**
- **Gotcha baked into the hook:** `root_cert` must terminate in a *self-signed* root. LE's
  `chain.pem` stops at an intermediate, so the hook appends **ISRG Root X1**; without it vCenter
  rejects the PUT with *"trustAnchors must be non-empty."*

Issue (one-time) — on `gw-vcf`:

```bash
sudo certbot certonly --dns-cloudflare --dns-cloudflare-credentials /root/.secrets/cf.ini \
  --key-type rsa --cert-name vcenter-vcf --deploy-hook /usr/local/bin/push-cert-to-vcenter.sh \
  -d vcenter.vcf.sampsoftware.net
```
`push-cert-to-vcenter.sh` is version-controlled here; it reads vCenter admin creds from
`/root/.secrets/vcenter.cred` (lab-only). Verify: `curl https://vcenter.vcf.sampsoftware.net/ui/`
→ trusted (no `-k`), `ssl_verify_result=0`.

## ESXi — reverse-proxied via the gateway (`gateway/`)

The gateway's Traefik holds a `*.vcf.sampsoftware.net` LE cert (ACME, auto-renew) and proxies
`esxi-t620.vcf.sampsoftware.net` → `https://192.168.20.13` behind a `local-network-only` allowlist
(backend self-signed via `insecureSkipVerify`). Point `esxi-t620.vcf` DNS at the gateway (`.5`) on
the UDM. Covers the **web UI + API over 443**; VM consoles / OVF transfers on 902 still hit the
host's self-signed cert (expected). Build runbook: [`gateway/README.md`](gateway/README.md).

## Tanzu appliance — cert pushed into its own Traefik

The appliance self-signs at first boot (`ovf-firstboot.sh`) and mounts `/opt/traefik/certs`. So:

- **`issue-appliance-cert.sh`** issues the LE wildcard (`tanzu.vcf` + `*.tanzu.vcf` + `*.sys.tanzu.vcf`
  + `*.apps.tanzu.vcf`) via DNS-01.
- **`deploy-cert-to-appliance.sh`** is its `--deploy-hook`: copies `fullchain`/`privkey` into the
  appliance's `/opt/traefik/certs/` and restarts Traefik — renewals auto-push. Confirm the target
  filenames once (`grep -rEi 'certFile|keyFile' /opt/traefik/config`).

The appliance's **internal** BOSH/GoRouter certs stay self-signed (normal); replacing the edge cert
gives trusted Hub/Apps-Manager + `cf login` without `--skip-ssl-validation`.

## Wildcard rule (why several SANs)

A wildcard matches **exactly one label**, so each depth needs its own SAN: `*.tanzu.vcf` (hub/ops),
`*.sys.tanzu.vcf` (api/login/uaa), `*.apps.tanzu.vcf` (pushed apps); the gateway's `*.vcf` covers
the flat infra names like `esxi-t620.vcf`/`gw.vcf`. vCenter uses a single-name cert (its PNID).

## ⚠️ Cloudflare token

One token: **Zone → DNS → Edit on `sampsoftware.net` only**. Stored on `gw-vcf`:
`gateway/.env` (`CF_DNS_API_TOKEN`, for Traefik) and `/root/.secrets/cf.ini` (for certbot). The old
`secrets/cf.ini` is in git history — rotate it (a new token neutralizes the old; deleting the file
doesn't).

## Note: legacy `certbot.sh`

The old monolithic one-shot cert. Superseded by the three flows above; kept for reference.
