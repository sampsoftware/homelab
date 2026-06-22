# Legacy: TAS 4 foundation (retired)

**Everything in this directory is historical.** It documents the Tanzu Application Service 4
(Small Footprint) / Cloud Foundry foundation and its supporting VMs that ran on this lab on the
old `172.16.0.0/16` network. As of **June 2026** the ESXi host was rebuilt — it now holds only
the vCenter appliance and the Tanzu Platform appliance VM — and the lab moved to
`192.168.20.0/24` (VLAN 20). None of the hosts described here (bastion, PiHole, nvidia-server,
MicroCeph, OpsMan, the GoRouters, HAProxy) currently exist.

The Cloud Foundry platform is now the **Tanzu Platform appliance** — see the `tpa-homelab` repo.
For current lab IPs/networking, see `../../lab-ip-space.md`.

Kept for reference (the patterns and command cheatsheets are still instructive); do not treat
any address or hostname here as live.

| File | What it documented |
|---|---|
| `tanzu-application-service.md` | Installing OpsMan + TAS, domains/DNS, GoRouter certs, CredHub/UAA |
| `tas-tiles.md` | Installing TAS marketplace tiles (MySQL stub) |
| `spring-apps.md` | Deploying Spring apps to TAS (stub; live Spring work is now in `tpa-homelab`) |
| `common-operations.md` | Day-2 ops: SSH to the BOSH director, `bosh` CLI cheatsheet |
| `architecture.md` | HAProxy → GoRouter → Diego traffic-path diagram |
| `microceph.md` + `ceph-test.py` | MicroCeph S3-compatible object storage + RGW setup + test script |
| `gpu.md` + `nvidia-k80-ubuntu22-headless.sh` | Nvidia Tesla K80 passthrough, CUDA 11.4, headless driver install |
| `deployment.yaml` | The ~11k-line BOSH/CF deployment manifest (mostly base64 blobs) |
