> **⚠️ HISTORICAL — retired.** Documents the TAS 4 / BOSH foundation and its supporting VMs
> (bastion, PiHole, the Nvidia GPU server, MicroCeph) that ran on the old `172.16.0.0/16` lab
> network. **That infrastructure no longer exists.** The lab is now `192.168.20.0/24` (VLAN 20)
> and the Cloud Foundry platform is the Tanzu Platform appliance — see `../../../tpa-homelab`.
> All IPs/names below are historical. Kept for reference only. See `./README.md`.

# Common Operations

## Connect to Opsman and use BOSH CLI

Operations Manager Director is the first VM created. To access VMs or other SSH-able components, first ssh to the director, and then use the bosh cli.

### SSH to Bosh Director

Ensure the public key is specified. 

From your workstation or linux bastion:

ssh ubuntu@[fqdn] -i path/to/publickey

ssh ubuntu@opsman.tas.lab.sampsoftware.net -i secret/id_opsman

### Set environment variables



export BOSH_CLIENT=ops_manager \
BOSH_CLIENT_SECRET=some_secret \
BOSH_CA_CERT=/var/tempest/workspaces/default/root_ca_certificate \
BOSH_ENVIRONMENT=172.16.3.2 bosh

export BOSH_CLIENT=ops_manager \
BOSH_CLIENT_SECRET=eiZWk3ARtNfEkkZc082NbyQ-rbzmxnxn \
BOSH_CA_CERT=/var/tempest/workspaces/default/root_ca_certificate \
BOSH_ENVIRONMENT=172.16.3.2

### BOSH CLI Examples

|Action|Command|
|-|-|
|List deployments|`bosh deployments`|
|Create alias for an env|`bosh alias-env MY-ENV -e DIRECTOR-IP-ADDRESS --ca-cert /var/tempest/workspaces/default/root_ca_certificate`|
|*example*|`bosh alias-env lab -e 172.16.3.2  --ca-cert /var/tempest/workspaces/default/root_ca_certificate`|
|Cloud Check|`bosh -e ENV -d deployment-name cloud-check`|
|*example*|`bosh -e lab -d cf-a0fa80b38de0ca83b9ac cloud-check`|



