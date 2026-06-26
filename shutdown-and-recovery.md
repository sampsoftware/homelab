# Shutdown & power-recovery runbook

How to cleanly power down the lab (single Dell T620, ESXi 7.0.3 `esxi-t620`) and what to expect
when it comes back from a power outage. The host runs three VMs, all with VMware Tools:

| VM | Role | IP |
|---|---|---|
| `vcenter-vcf` | VCSA 8.0.3 — management plane (a VM *on* the host it manages) | 192.168.20.14 |
| `gw-vcf` | cert/ingress gateway (Traefik + certbot) | 192.168.20.5 |
| `tanzu-platform-appliance` | the platform — Docker + BOSH CPI + Postgres/ClickHouse/Hub | 192.168.20.12 |

## Host autostart / autostop (configured)

Host autostart is enabled and ordered (set via `govc host.autostart.*`):

| Order | VM | Start delay | Stop action | Stop delay |
|---|---|---|---|---|
| 1 | `vcenter-vcf` | 180 s | guestShutdown | 120 s |
| 2 | `gw-vcf` | 30 s | guestShutdown | 30 s |
| 3 | `tanzu-platform-appliance` | 240 s | guestShutdown | 120 s |

**Start** runs low→high (vCenter first so the management plane is up; the heavy appliance last so it
isn't fighting boot for CPU/IO). **Stop** runs the reverse — the **appliance shuts down first** (with
120 s to let Docker/BOSH/Postgres/ClickHouse flush) and **vCenter last**. The appliance doesn't need
vCenter at runtime; the ordering is about graceful flush + boot resource staging, not a hard dependency.

> This means an ESXi host **Shut Down** (host client or `esxcli system shutdown`) now triggers a
> *graceful, ordered* guest shutdown on its own. The manual procedure below is for when you want to
> drive it yourself or verify each guest is down before pulling power.

## `govc` access (from this dev container)

The `homelab.env` secret has `VCENTER_*` creds but its `VCENTER_URL` is **stale** (points at the
decommissioned `.11` `vcenter.lab`). Use the current vCenter explicitly:

```bash
set -a; . /run/secrets/codedev/homelab.env; set +a
export GOVC_URL="https://192.168.20.14" GOVC_INSECURE=1
export GOVC_USERNAME="$(printf '%s' "$VCENTER_USER"|tr -d '\r\n')"
export GOVC_PASSWORD="$(printf '%s' "$VCENTER_PASSWORD"|tr -d '\r\n')"
govc about      # sanity
```

(Values in the secret have CRLF line endings — strip `\r` or govc reports "specify a URL".)

## Planned graceful shutdown

The host's autostop will do this in order on a host Shut Down, but to drive it manually (and confirm
each step) — shut guests down by statefulness, host last:

1. **Quiesce the appliance** (optional): stop `cf push`ing; if a deploy is mid-flight let BOSH settle
   (`bosh tasks` empty — see `../tpa-homelab/tanzu-platform-appliance.md`).
2. **Stop the appliance and wait for power-off** — the one that matters (let it flush):
   ```bash
   govc vm.power -s tanzu-platform-appliance     # -s = guest shutdown via Tools
   govc vm.info tanzu-platform-appliance | grep -i power   # wait for poweredOff
   ```
3. **Stop `gw-vcf`:** `govc vm.power -s gw-vcf`
4. **Stop vCenter LAST.** Once it's down you lose `govc`/the UI, so either run
   `govc vm.power -s vcenter-vcf` and finish from the **ESXi host client**, or do steps 2–4 entirely
   from the ESXi host client so you're never dependent on vCenter.
5. **Shut down ESXi** — host client → *Shut Down*, or SSH to the host:
   ```bash
   esxcli system shutdown poweroff -d 30 -r "planned maintenance"
   ```
   Single host, so no maintenance mode / vMotion needed once the VMs are off.

## Recovery from a flat (unclean) power outage

When power returns:

1. **Host POST + boot** — the T620 has a long POST (several minutes) before ESXi loads.
2. **Autostart fires** in order: vCenter (+180 s) → gw-vcf (+30 s) → appliance (+240 s). All three now
   come back on their own — no manual power-on needed.
3. **vCenter (VCSA)** usually self-recovers from an unclean stop but can take 10–15 min to bring all
   services up. If the UI is unhappy: SSH to VCSA → `service-control --status --all`, or reboot it.
4. **The appliance after an unclean boot** re-runs its inception chain and **reconverges the whole
   BOSH fleet** — expect a high load spike (~100–300) for 30–60+ min, then it settles. It self-heals;
   watch:
   ```bash
   ssh -i ~/.ssh/id_appliance vcap@192.168.20.12
   journalctl -fu tile-installer          # convergence progress
   # then, inside opsman, bosh -d <dep> instances --ps  → expect all 'running'
   ```
   - The trusted-cert state is **persistent** (the `hub_ca_certificate` / ISRG Root X1 fix lives in
     OpsManager config), so the `frpc` cert trap does **not** re-trigger on reboot. See
     `../tpa-homelab/tanzu-platform-appliance.md` → *Custom edge certificate*.
   - Risk to watch: unclean stop of Postgres/ClickHouse/BOSH blobstore on the 200 GB disk. ext4
     journaling normally recovers; if a tile won't come up, read that failed job's logs first.
5. **Verify** once settled: edge endpoints return 200/302 with the LE cert
   (`hub.`, `apps.sys.`, `login.sys.`, `api.sys.` `…tanzu.vcf.sampsoftware.net`).

## Scripts (this repo)

Two scripts automate the cycle. Both read creds from `homelab.env`, tolerate its CRLF endings, and
honor `DRYRUN=1` (log actions, touch nothing):

- **`lab-shutdown.sh`** — graceful, ordered guest shutdown (`tanzu-platform-appliance` → `gw-vcf` →
  `vcenter-vcf`, with a per-VM grace window and a forced power-off only if a guest overstays — e.g.
  the appliance under heavy load can have **dead VMware Tools**, so it gets hard-killed), then powers
  off the host (`govc host.shutdown -f`). It talks to the ESXi host by **direct IP** (`ESXI_IP`,
  default .13→.10) — *not* `ESXI_URL`/`esxi-t620.vcf`, which is gw-vcf's proxy that this very script
  shuts down (same gateway-inception trap as the iDRAC). Run a `DRYRUN=1` pass first.
- **`lab-poweron.sh`** — powers the host back on via the **iDRAC Redfish API** (`curl`, since IPMI/623 is disabled on this iDRAC);
  host autostart then restores the VMs.

## Unattended daily off (7 pm) / on (7 am)

```cron
# on the always-on scheduler host (see constraint), crontab -e:
0 19 * * *  /path/to/lab-shutdown.sh >> /var/log/lab-shutdown.log 2>&1
0  7 * * *  /path/to/lab-poweron.sh  >> /var/log/lab-poweron.log  2>&1
```

**Why two mechanisms:** once `lab-shutdown.sh` powers the host off it's in soft-off (S5) — ESXi is
gone, so the *only* thing that can bring it back is the out-of-band controller (**iDRAC**, alive on
aux power whenever the PSU has AC). WoL is unreliable on ESXi after a clean poweroff; use the iDRAC
(Redfish over 443 here, since IPMI-over-LAN is disabled).

> ⚠️ **The scheduler must be an always-on machine that is NOT on the T620.** `gw-vcf`, the appliance
> and vCenter all die with the host, so none of them can power it back on. Use a tiny always-on box
> (Raspberry Pi), the Windows workstation's Task Scheduler (invoking WSL), or similar — with `govc` +
> `jq` (shutdown) and `curl` + `python3` (power-on) on PATH and network reach to both the ESXi host
> and the iDRAC.

**Prerequisites:**

- **iDRAC credentials** — present and validated. `IDRAC_USERNAME` / `IDRAC_PASSWORD` (and `IDRAC_URL`)
  are in `homelab.env`; `DRYRUN=1 bash lab-poweron.sh` authenticates and reads `PowerState`. Note
  `lab-poweron.sh` targets the iDRAC's **raw IP `192.168.20.9`** (`IDRAC_IP`), *not* the proxied name
  `idrac-t620.vcf.sampsoftware.net` — that name points at gw-vcf's Traefik (trusted browser UI), and
  gw-vcf is down at power-on time. IPMI udp/623 is disabled, so Redfish over 443 is used (not `ipmitool`).
- **`curl` + `python3`** on the scheduler host (both standard; no `ipmitool` needed).
- A `DRYRUN=1` pass of each script from the scheduler host to confirm creds/reachability.
- **Watch the first few cycles:** the appliance reconverges its BOSH fleet on every cold boot (high
  load 30–60 min, then settles; cert state persists). Confirm it reliably reaches "all running"
  inside the 7 am→usable window before trusting it unattended.

## Still recommended

- **UPS with automated shutdown** (NUT / `apcupsd`) — point its on-battery hook at **`lab-shutdown.sh`**
  so a power event triggers the same clean, ordered shutdown. This is what turns a "flat power outage"
  into a *graceful* shutdown and is the single biggest protection for the stateful appliance —
  autostart and the 7 am cron only help on the way back up, not on the way down.
- Fix the stale `homelab.env` `VCENTER_URL` (`.11`/`vcenter.lab` → `.14`/`vcenter.vcf`).
