
## Set these VM parameters:
# pciPassthru.use64bitMMIO = "TRUE"
# pciPassthru.64bitMMIOSizeGB = 128

set -x

sudo apt remove --purge '^nvidia-.*' '^cuda.*'
sudo apt -y autoremove 
sudo apt clean

sudo add-apt-repository ppa:cloudhan/liburcu6
sudo apt update
sudo apt install liburcu6

sudo apt install nvidia-headless-470-server

wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/cuda-ubuntu2004.pin
sudo mv cuda-ubuntu2004.pin /etc/apt/preferences.d/cuda-repository-pin-600
wget https://developer.download.nvidia.com/compute/cuda/11.4.4/local_installers/cuda-repo-ubuntu2004-11-4-local_11.4.4-470.82.01-1_amd64.deb
sudo dpkg -i cuda-repo-ubuntu2004-11-4-local_11.4.4-470.82.01-1_amd64.deb
sudo apt-key add /var/cuda-repo-ubuntu2004-11-4-local/7fa2af80.pub
sudo apt-get update
sudo apt-get -y install cuda-toolkit-11-4

sudo apt install nvidia-utils-470-server


pip install torch==1.12.1+cu113 torchvision==0.13.1+cu113 torchaudio==0.12.1 --extra-index-url https://download.pytorch.org/whl/cu113
pip install "numpy<2.0.0"
