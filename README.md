# Samp Lab

A physical homelab for VMware virtualization and Cloud Foundry / Tanzu container automation,
on a single Dell PowerEdge T620. This repo is the operator's runbook + network reference.

> **Network moved to VLAN 20 / `192.168.20.0/24`.** The old `172.16.0.0/16` ("the_lab")
> addressing is retired. See `lab-ip-space.md` for the current map.
>
> **The TAS 4 foundation is retired.** The host was rebuilt (June 2026) and now runs only
> vCenter and the Tanzu Platform appliance. The old TAS/BOSH stack and its supporting VMs
> (bastion, PiHole, GPU server, MicroCeph) are gone — their docs are archived under
> `docs/legacy-tas/`. The current Cloud Foundry platform lives in the **`tpa-homelab`** repo.

## Live services

| Service | URL / name | IP | Notes | Credentials |
|---|---|---|---|---|
| ESXi host | `esxi-t620.lab.sampsoftware.net` | `192.168.20.10` / `.13` | vSphere 7.0.3 | root / in password manager |
| vCenter | <https://vcenter.lab.sampsoftware.net> | `192.168.20.11` | manages the SDDC | `administrator@vsphere.local` / in password manager |
| Tanzu Platform appliance | `*.tanzu.vcf.sampsoftware.net` | `192.168.20.12` | **deploy pending** — see `tpa-homelab` + `certs.md` | retrieved from the appliance |

## Hardware

### [PowerEdge T620](poweredge.md)

Dell PowerEdge T620 (≈2013, bought refurbished 2018). Dual Xeon E5-2640 (Sandy Bridge, 2×6
cores), **256 GB DDR3** (16×16 GB PC3-12800R), PERC RAID + mixed HDD/SSD and 2× NVMe on PCIe.
The CPU is several generations below VMware's supported floor, so ESXi installs after accepting
a compatibility warning. A Windows VM has never installed successfully (suspected CPU). NSX is
not installed (suspected CPU incompatibility), so there is no SDN overlay.

### [UniFi](unifi.md)

A Ubiquiti **UDM Pro** provides routing, VLANs, and **lab DNS** (the resolver at
`192.168.20.1`). PiHole — the previous lab DNS — is retired.

## Networking & virtualization

- [Naming scheme](naming.md) — the `<workload>.<substrate>.sampsoftware.net` taxonomy; VMware
  under `vcf.`, personal under `lab.`.
- [IP space](lab-ip-space.md) — the current network/IP source of truth (VLAN 20).
- [Virtualization & services](virtualization.md) — installing/configuring ESXi and vCenter;
  recovering VCSA passwords headless.
- [Certificate plan](certs.md) — trusted TLS via a gateway VM (Traefik + ACME, auto-renewing):
  infra hosts proxied under `*.vcf`, the appliance cert pushed to its own Traefik.
- [Gateway](gateway/README.md) — the Traefik/ACME gateway VM that fronts vCenter/ESXi.

## Archived

- [`docs/legacy-tas/`](docs/legacy-tas/README.md) — the retired TAS 4 / BOSH foundation and its
  supporting VMs. Historical reference only; nothing there is live.
