> **⚠️ HISTORICAL — retired.** Documents the TAS 4 / BOSH foundation and its supporting VMs
> (bastion, PiHole, the Nvidia GPU server, MicroCeph) that ran on the old `172.16.0.0/16` lab
> network. **That infrastructure no longer exists.** The lab is now `192.168.20.0/24` (VLAN 20)
> and the Cloud Foundry platform is the Tanzu Platform appliance — see `../../../tpa-homelab`.
> All IPs/names below are historical. Kept for reference only. See `./README.md`.

```mermaid
block-beta
    columns 1
    client["Inbound traffic"]
    space
    ooxy["HA Proxy 
        172.16.2.10
        *.system.tas.lab.sampsoftware.net
        *.apps.tas.lab.sampsoftware.net
        haproxy.tas.lab.sampsoftware.net
        "]
    space
    block:router
        gorouter1 ["
            Gorouter 
            127.16.3.11
            "]
        gorouter2 ["
            Gorouter 
            127.16.3.11
            "]
        gorouter3 ["
        Gorouter 
            127.16.3.11
            "]
    end
    diego_compute
    client --> haproxy
    haproxy --> gorouter1
    haproxy --> gorouter2
    haproxy --> gorouter3
    gorouter1-->diego_compute
    gorouter2-->diego_compute
    gorouter3-->diego_compute

    style client word-wrap: break-word;
```