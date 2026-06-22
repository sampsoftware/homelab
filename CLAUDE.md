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
~10 TB mixed HDD/SSD + 2× NVMe on PCIe) runs **ESXi / vSphere 7.0.3**. The CPU is several
generations below VMware's supported floor, so installs proceed only after accepting a
compatibility warning; NSX is deliberately **not** installed (suspected CPU
incompatibility), so there is no SDN overlay. Networking is a **Ubiquiti UDM Pro** providing
VLANs on **`192.168.20.0/24` (VLAN 20)**; the UDM (`192.168.20.1`) is also the lab DNS.

As of **June 2026 the host was rebuilt** and holds **only two VMs**: the vCenter appliance
(`192.168.20.11`) and the Tanzu Platform appliance (`192.168.20.12`, deploy pending). The
earlier **TAS 4 / BOSH foundation** and its supporting VMs (PiHole, MicroCeph, an Ubuntu
bastion, an Nvidia-GPU server) are **retired** — their docs are archived under
`docs/legacy-tas/`. The current Cloud Foundry platform is the Tanzu Platform appliance,
configured from the sibling **`tpa-homelab`** repo.

## Doc map

**Current docs:**

| File | What it covers |
|---|---|
| `README.md` | Top-level index: live services, hardware links, pointers |
| `poweredge.md` | The T620 host — full bill of materials, CPU/RAM/disk detail |
| `lab-ip-space.md` | **The IP/network source of truth** — VLAN 20 assignment table, DNS, upstream |
| `naming.md` | **The DNS naming scheme** — the `<workload>.<substrate>.sampsoftware.net` taxonomy; why VMware lives under `vcf.`, personal under `lab.` |
| `virtualization.md` | Installing & configuring ESXi and vCenter; recovering VCSA passwords headless |
| `unifi.md` | Ubiquiti UDM Pro / UniFi Identity Enterprise console + credentials pointers |
| `certs.md` | **The certificate plan** — trusted TLS via a gateway VM (Traefik + ACME), auto-renewing; how infra hosts are proxied and the appliance cert is pushed |
| `gateway/` | **The cert/ingress gateway VM** — Traefik + ACME scaffold (compose, config, runbook) that reverse-proxies vCenter/ESXi under `*.vcf` with auto-renewing LE certs |
| `issue-appliance-cert.sh` | Issue the LE wildcard for the Tanzu appliance (`*.tanzu.vcf.sampsoftware.net` + sys/apps), with a deploy hook |
| `deploy-cert-to-appliance.sh` | certbot deploy-hook: push the cert into the appliance's Traefik (`/opt/traefik/certs`) and reload |
| `certbot.sh` | Legacy one-shot wildcard cert (LE + Cloudflare DNS-01). Superseded by the gateway scheme in `certs.md`; kept for reference |
| `vcsa-shell-access.md` | Reference: why VCSA's appliancesh blocks scripted SSH, and the gotchas (faillock, ANSI prompts, PAM pwhistory). The *capability* lives in the `vcsa-drive` skill |
| `.claude/skills/vcsa-drive/` | **Skill** — drive interactive VCSA admin tools headlessly (reset a lost SSO password, change appliance root). `SKILL.md` + the `vcsa_drive.py` pty helper. See `.claude/README.md` |

**Archived** (`docs/legacy-tas/` — the retired TAS 4 / BOSH foundation; historical only):
`tanzu-application-service.md`, `tas-tiles.md`, `spring-apps.md`, `common-operations.md`,
`architecture.md`, `microceph.md` + `ceph-test.py`, `gpu.md` + `nvidia-k80-ubuntu22-headless.sh`,
`deployment.yaml`. See `docs/legacy-tas/README.md`.

## Network history

The current docs were reconciled to live reality in **June 2026** (verified against the
ESXi/vCenter inventory + DNS). The repo previously documented a `172.16.0.0/16` ("the_lab")
network; that addressing is **retired** and survives only in `docs/legacy-tas/`. If you find a
`172.16.x.x` address anywhere outside that directory, it's a miss — reconcile it to VLAN 20.

## Key facts an agent needs (verified June 2026)

- **Network:** lab is on **`192.168.20.0/24`, VLAN 20**; gateway **and DNS** are the UDM Pro at
  `192.168.20.1`. Uplink is Xfinity cable (~1.2 Gbit) → UDM Pro.
- **Core endpoints:** ESXi host `esxi-t620.lab.sampsoftware.net` (`192.168.20.10` / `.13`,
  vSphere 7.0.3), vCenter `vcenter.lab.sampsoftware.net` (`192.168.20.11`,
  `administrator@vsphere.local`), the cert/ingress gateway VM `gw-vcf` (`192.168.20.5`,
  Ubuntu/Docker — see `gateway/`), and the Tanzu Platform appliance (`192.168.20.12`, deploy
  pending; a stale appliance VM is still on the host, powered off, awaiting replacement).
- **DNS:** the UDM Pro at `192.168.20.1` is the lab resolver (PiHole is retired). For the
  appliance, add wildcard `*.tanzu.vcf.sampsoftware.net → 192.168.20.12` on the UDM (LAN-only
  split-horizon — see `certs.md`).
- **Naming:** VMware lab lives under **`vcf.sampsoftware.net`** (`<workload>.<substrate>` —
  `vcenter.vcf`, `esxi-t620.vcf`, `tanzu.vcf`); **personal** `sampstack` keeps `*.lab.sampsoftware.net`.
  See `naming.md`. Infra hosts still answer on their old `*.lab` names today; the `vcf` names are
  gateway front-doors (`gateway/`).
- **Domains:** the appliance is under
  `*.tanzu.vcf.sampsoftware.net` (sys `*.sys.tanzu.vcf…`, apps `*.apps.tanzu.vcf…`). Public certs come
  from Let's Encrypt via Cloudflare DNS-01 — see `certs.md`.

## Terminology note (relevant to current work)

The lab documents **TAS = Tanzu Application Service** (the BOSH/OpsMan-deployed Cloud Foundry
product). VMware/Broadcom has since rebranded this line to **Tanzu Platform** — "Tanzu
Platform for Cloud Foundry" (**TPCF**, you'll see `tpcf` in `certbot.sh`) and "Tanzu Platform
for Applications" (**TPA**). The companion `tpa-homelab` repo is about deploying the
newer Tanzu Platform onto this same vCenter. When docs say "TAS" and newer material says
"Tanzu Platform"/"TPCF"/"TPA", they're the same product family at different eras — keep the
distinction explicit rather than silently conflating them.

## Conventions & gotchas

- **Editing docs:** match the existing voice — first-person operator notes, links to source
  docs, and candid "ask me how I know" caveats. Don't sanitize that into corporate prose.
- **Don't read `docs/legacy-tas/deployment.yaml` whole** (625 KB, ~11k lines, huge embedded
  base64). `grep` for the property/job you care about.
- **ESXi CPU warning is expected**, not a bug to fix — the Sandy Bridge CPU is intentionally
  run below VMware's supported floor.
- This repo's history shows it was mirrored from `github.com/cgsamp/homelab`; the canonical
  remote is now `sampsoftware/homelab`.

## ⚠️ Secrets are committed to this repo

`.gitignore` intends to ignore secrets but has a typo: it lists `secret/*` (singular) while
the actual directory is `secrets/` (plural), so **nothing in `secrets/` is ignored**. As a
result `secrets/cf.ini` (a Cloudflare API token) is tracked, and several live-looking
credentials are pasted into the now-archived markdown under `docs/legacy-tas/` (MicroCeph
access/secret keys in `microceph.md`, a `BOSH_CLIENT_SECRET` in `common-operations.md`, a
CredHub key + GoRouter material in `tanzu-application-service.md`). These are for the retired
foundation, but rotate anything that was reused.

- **Do not add new secrets** to tracked files. If you must reference one, point at the
  password manager, not the value.
- The Cloudflare token in `secrets/cf.ini` should be **rotated** (it's in git history, so
  removing the file is not enough) and the `.gitignore` typo fixed (`secret/*` → `secrets/*`).
  Don't do this unprompted — flag it and let the operator decide.
