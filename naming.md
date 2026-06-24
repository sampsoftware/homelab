# DNS naming scheme

How names are laid out for this lab, and why. The scheme is a **two-axis taxonomy** under the
`sampsoftware.net` Cloudflare zone:

```
<workload>.<substrate>.sampsoftware.net
<host>.<substrate>.sampsoftware.net
```

- **substrate** — what something runs *on* / the platform: `vcf` (this VMware estate),
  and later potentially `gcp`, `aws`, … The two axes move independently, so you can express
  the same workload on different substrates (`tanzu.vcf` vs `tanzu.gcp`) and different
  workloads on one substrate (`tanzu.vcf` vs `otherthing.vcf`).
- **workload** — the tenant running on the substrate: `tanzu`, …
- **host** — a bare infrastructure box of the substrate: `esxi-t620`, `vcenter`, `gw`.

## Why `vcf`

`vcf` = **VMware Cloud Foundation** — Broadcom's current branding for the VMware platform,
and an accurate name for the *substrate*. Deliberately not:

- **`sddc`** — every virtualized estate is a "software-defined data center"; the term is a
  category, not a discriminator, so it carries no information.
- **`vmware`** — that's the *vendor*, and Tanzu is *also* a VMware product, so `tanzu.vmware`
  would be redundant. Naming the substrate by the *platform* (`vcf`) keeps the workload and
  substrate axes from colliding — `tanzu.vcf` reads cleanly as "Tanzu on VMware Cloud Foundation".
- **a single flat `tanzu.…`** — that brands the whole estate after one workload; the day a
  Windows VM or a k8s cluster lands, the name lies.

## Separation from personal projects

`sampsoftware.net` carries two distinct worlds, split at the second label:

| Zone | What lives there |
|---|---|
| `*.lab.sampsoftware.net` | **Personal** projects — the `sampstack` services (hub, registry, pgadmin, vikunja, home-assistant). Untouched by this lab. |
| `*.vcf.sampsoftware.net` | **This VMware lab** — ESXi/vCenter infra and the Tanzu platform tenant. |

Both are records in the same Cloudflare zone, so **one `CF_DNS_API_TOKEN` (Zone:DNS:Edit on
`sampsoftware.net`) issues certs for everything** — but the namespaces never mix.

## The tree

```
sampsoftware.net
├── lab.                          personal (sampstack — separate project, untouched)
└── vcf.                          the VMware Cloud Foundation estate
    ├── esxi-t620.vcf…            ESXi host 1
    ├── esxi-02.vcf…              ESXi host 2 (future)
    ├── vcenter.vcf…              vCenter
    ├── gw.vcf…                   the Traefik/ACME gateway VM (see ../gateway/)
    ├── tanzu.vcf…                ← Tanzu Platform appliance (a tenant)
    │   ├── hub / ops .tanzu.vcf…
    │   ├── api.sys.tanzu.vcf…    (+ *.sys.tanzu.vcf…)
    │   └── *.apps.tanzu.vcf…     pushed CF apps
    └── otherthing.vcf…           future tenant
```

Infra hosts (`vcenter.vcf`) and tenant roots (`tanzu.vcf`) **coexist directly under `vcf`** —
both are just single labels in the substrate. A tenant that needs depth (Tanzu's sys/apps)
grows its own sub-tree; a flat tenant or host just sits at the top level.

### Host naming scales on the *leftmost* label

Multi-host growth is handled by the host label, not the substrate label: `esxi-t620.vcf`,
`esxi-02.vcf`, … Never use a bare `esxi.vcf` — it doesn't scale to a second host.

## Certificate implications

A TLS/DNS wildcard matches **exactly one label**, so each depth level needs its own wildcard.
The gateway carries:

| Cert (wildcard) | Covers |
|---|---|
| `*.vcf.sampsoftware.net` (+ apex) | `esxi-t620.vcf`, `esxi-02.vcf`, `vcenter.vcf`, `gw.vcf`, and bare tenant roots like `tanzu.vcf` |
| `*.tanzu.vcf.sampsoftware.net` | `hub.tanzu.vcf`, `ops.tanzu.vcf` |
| `*.sys.tanzu.vcf.sampsoftware.net` | `api`, `login`, `uaa`, Apps Manager |
| `*.apps.tanzu.vcf.sampsoftware.net` | pushed CF apps |

Flat tenants/hosts ride `*.vcf` for free; only depth-needing tenants (Tanzu) add wildcards.
Cert mechanics — issuance, the gateway, the appliance — are in [`certs.md`](certs.md).

## Current state

The scheme is largely realized:

- **vCenter** was rebuilt natively on `vcf`: PNID `vcenter.vcf.sampsoftware.net` (VCSA 8.0.3,
  `192.168.20.14`), carrying its own trusted LE cert on the appliance itself (a reverse proxy
  can't front vCenter — SSO binds to the PNID; see [`certs.md`](certs.md)).
- **ESXi** keeps its host/PNID name `esxi-t620.lab.sampsoftware.net` (changing an ESXi hostname
  is in-place but not yet done); it's reached *trusted* via the gateway front-door
  `esxi-t620.vcf.sampsoftware.net` (`gateway/`), since ESXi has no SSO to upset.
- **Tanzu appliance** is natively `tanzu.vcf.sampsoftware.net` (its `tpa-homelab/config.json`
  domain, set at deploy).

So the only `lab` remnant in the VMware estate is ESXi's own management hostname; everything an
operator touches is under `vcf`.
