> **⚠️ HISTORICAL — retired.** Documents the TAS 4 / BOSH foundation and its supporting VMs
> (bastion, PiHole, the Nvidia GPU server, MicroCeph) that ran on the old `172.16.0.0/16` lab
> network. **That infrastructure no longer exists.** The lab is now `192.168.20.0/24` (VLAN 20)
> and the Cloud Foundry platform is the Tanzu Platform appliance — see `../../../tpa-homelab`.
> All IPs/names below are historical. Kept for reference only. See `./README.md`.

# Microceph

Microceph is a lightweight implementation of Ceph. It is not (yet?) fully complete, but works well enough at this time.

## Install MicroCEPH


## Installation

1. Provision a Ubuntu server
1. Follow this procedure to install the software:
    1. Use the below, except maybe use larger disk. I used `sudo microceph disk add loop,25G,3`
    1. https://canonical-microceph.readthedocs-hosted.com/en/reef-stable/tutorial/single-node/
1. Follow this to enable the S3-compatible RGW service
    1. I used `sudo microceph enable rgw --port 80` for clarity, even though I believe 80 is the default
    1. https://canonical-microceph.readthedocs-hosted.com/en/reef-stable/how-to/enable-service-instances/

## Create user

On the ceph server, use the ceph cli to create a user
1. https://docs.ceph.com/en/latest/rados/operations/user-management/#managing-users
1. I used 'cgsamp@ceph-lab:~$ sudo radosgw-admin user create --uid=tanzu --display-name="Tanzu"'
1. You will get a JSON in response that includes keys.access_key and keys.secret_key. Note those down. Although it is possible to use the ceph cli to retrieve them if you lose them.

## Test ceph

This is a bit harder than it seems, and requires a separate tool. It could also be done with Python or similar. It would be tough to do by hand because the requirements to hash the request headers is pretty tedious if you are not a computer.

1. Get `s3cmd`
    1. https://s3tools.org/s3cmd
    1. You can install this on your bastion or workstation, it does not have to be on the ceph server
    1. Make sure python and pip are updated. 'pip install s3cmd'
1. Create an FQDN
    1. Creating a compliant S3 bucket url requires adding things onto a hostname that does not work with just an ip address.
1. Configure s3cmd
    1. 's3cmd --configure'
    1. Enter access key and secret key
    1. Accept default region
    1. S3 endpoint is your ceph FQDN, e.g. ceph.lab.sampsoftware.net
    1. Bucket template is `%(bucket)s.ceph.lab.sampsoftware.net`
    1. I left all the encryption blank and said No to HTTPS
    







https://docs.ceph.com/en/latest/radosgw/

https://canonical-microceph.readthedocs-hosted.com/en/latest/

cgsamp@ceph-lab:~$ sudo radosgw-admin user create --uid=tanzu --display-name="Tanzu"
[sudo] password for cgsamp: 
{
    "user_id": "tanzu",
    "display_name": "Tanzu",
    "email": "",
    "suspended": 0,
    "max_buckets": 1000,
    "subusers": [],
    "keys": [
        {
            "user": "tanzu",
            "access_key": "0XUE6CGXNTENQ4F06BX7",
            "secret_key": "ehepFsMZVT7qZND8XVtv9c4YaB2Zuj2grgXG4Bwo"
        }
    ],
    "swift_keys": [],
    "caps": [],
    "op_mask": "read, write, delete",
    "default_placement": "",
    "default_storage_class": "",
    "placement_tags": [],
    "bucket_quota": {
        "enabled": false,
        "check_on_raw": false,
        "max_size": -1,
        "max_size_kb": 0,
        "max_objects": -1
    },
    "user_quota": {
        "enabled": false,
        "check_on_raw": false,
        "max_size": -1,
        "max_size_kb": 0,
        "max_objects": -1
    },
    "temp_url_keys": [],
    "type": "rgw",
    "mfa_ids": []
}
