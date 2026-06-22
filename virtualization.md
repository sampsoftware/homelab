# VMware / Unifi SDDC

## ESXi

The processor I use is unsupported. It is Sandy Bridge, and at least five architecture generations behind the bottom supported tier. That said, one can accept a warning, and then the installation proceeds. I did not have any trouble yet, but I hear products like NSX4 will have problems.
https://williamlam.com/2022/09/homelab-considerations-for-vsphere-8.html

### Installing ESXi

The basic process is to download the software from VMware, and then flash that to a bootable USB key. I used a personal Windows machine and Rufus to create the drive. It must be UEFI and use the xxx filesystem.

https://rufus.ie/en/

Put that into the USB port of the server and turn it on. Catch the boot sequence and enter the system configuation. Choose the USB key to boot from. Here is where I realised I needed UEFI. I used a keyboard and monitor connected directly to the server. It was connected to a DHCP network, although I changed the IP later.

This went actually quite smoothly despite my misgivings about the unsupported processor.

### Configuring ESXi

The splash page of the fully booted ESXi host will display a URL to access the host's management interface.

## vCenter

### Install Ubuntu Bastion

The installation process for the vCenter management tool requires mounting the ISO to a machine and running an executable. It is not itself bootable!

I downloaded the lastest Ubuntu Desktop ISO. I then uploaded it to a Datastore. Then I created a Virtual Machine with 2 CPU, 8GB RAM and a 50GB HDD on the nvmi datastore. 

--> While creating the VM, use the Optical Drive, select ISO from Datastore, and it will boot to the install location.

* Set static IP


### Install Pihole

Pihole is an open source DNS tool for Linux, originally targeted at low-power Raspberry Pis. It's main use case is to be the DNS server for your network and "black hole" requests from your workstation to ad networks, based on lists maintained by 3rd parties. In this case it is used as a plain DNS server to provide name-based access to the various lab services.

https://docs.pi-hole.net/main/basic-install/


### Install vCenter

Using the ESXi Host Manager tool, attach the vSphere ISO to your Ubuntu bastion vm

### Recovering / changing VCSA passwords headless

Lost the SSO `administrator@vsphere.local` password, or need to change the appliance `root`
password without the console? The `vcsa-drive` skill (`.claude/skills/vcsa-drive/`) scripts
appliancesh and the interactive admin tools over SSH. Background and gotchas:
`vcsa-shell-access.md`.

