# IP / network space

Current network source of truth. The lab runs on **VLAN 20, `192.168.20.0/24`**, gateway and
DNS `192.168.20.1` (the UniFi UDM Pro). The old `172.16.0.0/16` "the_lab" topology is retired —
see `docs/legacy-tas/` for the historical map.

> Verified against the live ESXi/vCenter inventory and DNS, June 2026. Static assignments below
> are confirmed; the DHCP pool is UDM-managed and not enumerated here.

## VLAN 20 — the lab (`192.168.20.0/24`)

| IP | DNS | Assignment |
|---|---|---|
| `192.168.20.1` | — | UDM Pro — gateway **and** lab DNS resolver |
| `192.168.20.10` | `esxi-t620.lab.sampsoftware.net` (vmk0) | ESXi host — management vmkernel |
| `192.168.20.11` | `vcenter.lab.sampsoftware.net` | vCenter Server appliance (VCSA 7.0.3) |
| `192.168.20.12` | `*.tanzu.vcf.sampsoftware.net` | Tanzu Platform appliance (**deploy pending**) |
| `192.168.20.13` | `esxi-t620.lab.sampsoftware.net` (vmk1) | ESXi host — second vmkernel (DNS resolves the name here) |

There are currently **only two VMs** on the host: the vCenter appliance and the Tanzu Platform
appliance. Everything else the lab once ran (bastion, PiHole, GPU server, MicroCeph, the TAS
foundation) is retired.

## DNS

- The **UDM Pro at `192.168.20.1`** is the lab resolver (PiHole, the former DNS, is retired).
- `esxi-t620` and `vcenter` `.lab.sampsoftware.net` resolve to their VLAN-20 addresses above.
- For the appliance, add wildcard DNS `*.tanzu.vcf.sampsoftware.net → 192.168.20.12` on the UDM
  for LAN clients (split-horizon — public names, internal IP). See `certs.md`.
- Stale public records may still linger for retired names (e.g. `bastion.lab.sampsoftware.net`
  → an old `172.16.x` address); ignore them.

## Upstream (as previously configured — verify if it matters)

- **Xfinity** cable, ~1.2 Gbit, into the UDM Pro WAN. WAN was a static `192.168.0.100` handed
  by the Xfinity gateway (`192.168.0.0/24`).
- UDM default network was `192.168.1.0/24` (VLAN 1).

These upstream details predate the VLAN-20 migration and weren't re-verified in this pass; treat
as historical until confirmed.

## Credentials

Not stored here. ESXi `root`, vCenter `administrator@vsphere.local`, and appliance credentials
live in the password manager / the host-side `homelab.env` secret (see `CLAUDE.md`).
