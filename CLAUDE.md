# homelab

Documentation (and a few helper scripts) for **Samp Lab**, a physical homelab used to
experiment with VMware virtualization and Cloud Foundry / Tanzu container automation.
This repo is **mostly prose + reference material**, not runnable software — there is no
build, no test suite, and no deploy pipeline. Treat it as the operator's runbook and
network reference for the lab. Most "work" here is editing markdown to keep it accurate,
or authoring the occasional helper script.

> Read this file, then the specific doc for whatever you're touching. When you change the
> physical/network reality of the lab, update the matching doc in the same change.

## The lab in one paragraph

A single Dell PowerEdge T620 (circa 2013, dual Xeon E5-2640 "Sandy Bridge", 256 GB DDR3,
~10 TB mixed HDD/SSD + 2× NVMe on PCIe) runs **ESXi / vSphere 8**. The CPU is several
generations below VMware's supported floor, so installs proceed only after accepting a
compatibility warning; NSX is deliberately **not** installed (suspected CPU
incompatibility), so there is no SDN overlay. Networking is a **Ubiquiti UDM Pro** providing
VLANs on `172.16.0.0/16`. On top of vSphere runs **Tanzu Application Service (TAS 4, Small
Footprint)** / Cloud Foundry via BOSH + Operations Manager, plus supporting VMs (PiHole DNS,
MicroCeph S3 storage, an Ubuntu bastion, an Nvidia-GPU server).

## Doc map

| File | What it covers |
|---|---|
| `README.md` | Top-level index: service URLs/credentials table, hardware links, TAS overview |
| `poweredge.md` | The T620 host — full bill of materials, CPU/RAM/disk detail |
| `virtualization.md` | Installing & configuring ESXi, the Ubuntu bastion, PiHole, vCenter |
| `unifi.md` | Ubiquiti UDM Pro / UniFi Identity Enterprise console + credentials pointers |
| `lab-ip-space.md` | **The IP/network source of truth** — VLANs, the `172.16.x.x` assignment table, DNS names |
| `microceph.md` | MicroCeph (lightweight Ceph) S3-compatible object storage + RGW user setup |
| `gpu.md` + `nvidia-k80-ubuntu22-headless.sh` | Nvidia Tesla K80 passthrough, CUDA 11.4, headless Ubuntu 22 driver install |
| `tanzu-application-service.md` | Installing OpsMan + TAS, domains/DNS, GoRouter certs, CredHub/UAA |
| `tas-tiles.md` | Installing TAS marketplace tiles (stub — MySQL only so far) |
| `spring-apps.md` | Deploying Spring apps to TAS (currently empty) |
| `common-operations.md` | Day-2 ops: SSH to BOSH director, `bosh` CLI env vars + command cheatsheet |
| `architecture.md` | Mermaid diagram of the HAProxy → GoRouter → Diego traffic path |
| `certs.md` | **The certificate plan** — LE + Cloudflare DNS-01, the two domain namespaces, LAN-only split-horizon DNS, and how the appliance cert is issued/injected |
| `certbot.sh` | Legacy one-shot wildcard cert (LE + Cloudflare DNS-01). Superseded by `certs.md`'s split-cert scheme; see notes there |
| `issue-appliance-cert.sh` | Issue the LE wildcard for the re-domained Tanzu appliance (`*.tpcf.lab.sampsoftware.net` + sys/apps), with a deploy hook |
| `deploy-cert-to-appliance.sh` | certbot deploy-hook: push the cert into the appliance's Traefik (`/opt/traefik/certs`) and reload |
| `ceph-test.py` | Small script to exercise the Ceph S3 endpoint |
| `vcsa-shell-access.md` | Reference: why VCSA's appliancesh blocks scripted SSH, and the gotchas (faillock, ANSI prompts, PAM pwhistory). The *capability* lives in the `vcsa-drive` skill |
| `.claude/skills/vcsa-drive/` | **Skill** — drive interactive VCSA admin tools headlessly (reset a lost SSO password, change appliance root). `SKILL.md` + the `vcsa_drive.py` pty helper. See `.claude/README.md` |
| `deployment.yaml` | **11k-line BOSH/CF deployment manifest** — mostly base64 blobs. Do NOT read whole; grep for the key you need |

## ⚠️ Network docs are obsolete

The `172.16.0.0/16` ("the_lab" VLAN) addressing used throughout this repo
(`lab-ip-space.md`, `README.md`, the TAS docs, `architecture.md`) is **no longer in use**.
The lab now runs on **`192.168.20.0/24`, VLAN 20**. Treat every `172.16.x.x` address here as
stale/historical. These docs predate the migration and haven't been updated — don't rely on
them for current IPs, and if you touch a networking doc, reconcile it to VLAN 20.

## Key facts an agent needs (verify against the docs before relying on these)

- **Network:** lab is on **`192.168.20.0/24`, VLAN 20** (gateway/DNS `192.168.20.1`). The
  `172.16.0.0/16` / `the_lab` addressing in `lab-ip-space.md` is **obsolete** (see warning
  above). Uplink is Xfinity cable (1.2 Gbit) → UDM Pro.
- **Core endpoints:** ESXi host `esxi-t620.lab.sampsoftware.net` (`172.16.1.100`),
  vCenter `vcenter.lab.sampsoftware.net` (`172.16.1.101`, `administrator@vsphere.local`),
  PiHole DNS `172.16.1.102`, OpsMan `172.16.2.2`, BOSH director `172.16.3.2`,
  GoRouters `172.16.3.11–15`.
- **DNS:** PiHole is the lab DNS. It does **not** do wildcard records natively — wildcard
  entries for TAS domains are added via a `dnsmasq.d` drop-in (see
  `tanzu-application-service.md`). The newer UDM Cloud Gateway also provides DNS.
- **Domains:** lab services live under `*.lab.sampsoftware.net`; TAS under
  `*.system.tas.lab.sampsoftware.net` and `*.apps.tas.lab.sampsoftware.net`. Public certs
  come from Let's Encrypt via Cloudflare DNS-01 (`certbot.sh`).
- **BOSH access:** SSH to OpsMan with the key, then use `bosh` with `BOSH_CLIENT` /
  `BOSH_CLIENT_SECRET` / `BOSH_CA_CERT` / `BOSH_ENVIRONMENT` — see `common-operations.md`.

## Terminology note (relevant to current work)

The lab documents **TAS = Tanzu Application Service** (the BOSH/OpsMan-deployed Cloud Foundry
product). VMware/Broadcom has since rebranded this line to **Tanzu Platform** — "Tanzu
Platform for Cloud Foundry" (**TPCF**, you'll see `tpcf` in `certbot.sh`) and "Tanzu Platform
for Applications" (**TPA**). The companion `tpa_lab`/`tpa_homelab` work is about deploying the
newer Tanzu Platform onto this same vCenter. When docs say "TAS" and newer material says
"Tanzu Platform"/"TPCF"/"TPA", they're the same product family at different eras — keep the
distinction explicit rather than silently conflating them.

## Conventions & gotchas

- **Editing docs:** match the existing voice — first-person operator notes, links to source
  docs, and candid "ask me how I know" caveats. Don't sanitize that into corporate prose.
- **Don't read `deployment.yaml` whole** (625 KB, ~11k lines, huge embedded base64). `grep`
  for the property/job you care about.
- **ESXi CPU warning is expected**, not a bug to fix — the Sandy Bridge CPU is intentionally
  run below VMware's supported floor.
- This repo's history shows it was mirrored from `github.com/cgsamp/homelab`; the canonical
  remote is now `sampsoftware/homelab`.

## ⚠️ Secrets are committed to this repo

`.gitignore` intends to ignore secrets but has a typo: it lists `secret/*` (singular) while
the actual directory is `secrets/` (plural), so **nothing in `secrets/` is ignored**. As a
result `secrets/cf.ini` (a Cloudflare API token) is tracked, and several live-looking
credentials are pasted into the markdown (MicroCeph access/secret keys in `microceph.md`,
a `BOSH_CLIENT_SECRET` in `common-operations.md`, a CredHub key + GoRouter material in
`tanzu-application-service.md`, passwords in `lab-ip-space.md`).

- **Do not add new secrets** to tracked files. If you must reference one, point at the
  password manager, not the value.
- The Cloudflare token in `secrets/cf.ini` should be **rotated** (it's in git history, so
  removing the file is not enough) and the `.gitignore` typo fixed (`secret/*` → `secrets/*`).
  Don't do this unprompted — flag it and let the operator decide.
