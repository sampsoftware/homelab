> **⚠️ HISTORICAL — retired.** Documents the TAS 4 / BOSH foundation and its supporting VMs
> (bastion, PiHole, the Nvidia GPU server, MicroCeph) that ran on the old `172.16.0.0/16` lab
> network. **That infrastructure no longer exists.** The lab is now `192.168.20.0/24` (VLAN 20)
> and the Cloud Foundry platform is the Tanzu Platform appliance — see `../../../tpa-homelab`.
> All IPs/names below are historical. Kept for reference only. See `./README.md`.

# GPU Installation

The Nvidia Tesla K80 is a pair of Tesla K40 w/ 12GB each, per card. It is a data center card, so has no monitor ports. It was Nvidia's most powerful card in 2014.

https://www.nvidia.com/en-gb/data-center/tesla-k80/
https://www.pcworld.com/article/436434/nvidia-reaches-high-on-graphics-performance-with-tesla-k80.html

## Architecture

This card uses the Kepler architecture, which is quite out of date.

## CUDA version

This card supports CUDA 11.4.

## Installation

Physical installation meant acquiring the T620 GPU Enablement Kit, which is a power card that installs under the motherboard and outputs power for up to 4 GPUs.

A specific cable was required.
https://www.ebay.com/itm/226156784263

## Driver installation

I used Ubuntu 22 desktop and server versions. Both ran into issues with compatability between this driver version and xorg libraries. This was resolved in later versions, but using the latest available Nvidia drivers is not an option as this card lost support. I was able to install the cards in headless mode.

I was also able to get the card working on Windows 11, and, in the VM, was able to set it as a video card and run some older games. (Not Cities Skylines 2.)

[Installation Script](Installation Script)