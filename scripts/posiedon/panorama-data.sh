#!/bin/bash

# this script should run as root
mv /etc/ssh/sshd_config /tmp/sshd_config
apt-get update && apt-get -y upgrade
apt-get install -y linux-headers-$(uname -r)
apt-get install -y build-essential make zlib1g-dev librrd-dev libpcap-dev autoconf libarchive-dev iperf3 htop bmon vim wget pkg-config git python-dev python-pip libtool
pip install --upgrade pip
#mv /tmp/sshd_config /etc/ssh/sshd_config

############################
### INSTALL APACHE2     ###
############################
apt-get install -y apache2
a2enmod userdir

######################
### EDIT /etc/hosts ##
######################

#cat << EOF >> /etc/hosts
#EOF

######################
### INSTALL CONDOR ###
######################

wget -qO - https://research.cs.wisc.edu/htcondor/ubuntu/HTCondor-Release.gpg.key | sudo apt-key add -
echo "deb http://research.cs.wisc.edu/htcondor/ubuntu/8.8/bionic bionic contrib" >> /etc/apt/sources.list
echo "deb-src http://research.cs.wisc.edu/htcondor/ubuntu/8.8/bionic bionic contrib" >> /etc/apt/sources.list

apt-get update && apt-get install -y htcondor

cat << EOF > /etc/condor/config.d/50-main.config
DAEMON_LIST = MASTER, COLLECTOR, NEGOTIATOR, SCHEDD

ALLOW_PSLOT_PREEMPTION = TRUE

CONDOR_HOST = `hostname` 

USE_SHARED_PORT = TRUE

NETWORK_INTERFACE = `curl -s http://169.254.169.254/latest/meta-data/local-ipv4 | cut -d'.' -f1,2,3`.*

# the nodes have shared filesystem
UID_DOMAIN = \$(CONDOR_HOST)
TRUST_UID_DOMAIN = TRUE
FILESYSTEM_DOMAIN = \$(FULL_HOSTNAME)

#--     Authentication settings
SEC_PASSWORD_FILE = /etc/condor/pool_password
SEC_DEFAULT_AUTHENTICATION = REQUIRED
SEC_DEFAULT_AUTHENTICATION_METHODS = FS,PASSWORD
SEC_READ_AUTHENTICATION = OPTIONAL
SEC_CLIENT_AUTHENTICATION = OPTIONAL
SEC_ENABLE_MATCH_PASSWORD_AUTHENTICATION = TRUE
DENY_WRITE = anonymous@*
DENY_ADMINISTRATOR = anonymous@*
DENY_DAEMON = anonymous@*
DENY_NEGOTIATOR = anonymous@*
DENY_CLIENT = anonymous@*

#--     Privacy settings
SEC_DEFAULT_ENCRYPTION = OPTIONAL
SEC_DEFAULT_INTEGRITY = REQUIRED
SEC_READ_INTEGRITY = OPTIONAL
SEC_CLIENT_INTEGRITY = OPTIONAL
SEC_READ_ENCRYPTION = OPTIONAL
SEC_CLIENT_ENCRYPTION = OPTIONAL

#-- With strong security, do not use IP based controls
HOSTALLOW_WRITE = *
ALLOW_NEGOTIATOR = *

EOF

condor_store_cred -f /etc/condor/pool_password -p c0nd0r_p00l

systemctl enable condor
systemctl restart condor

#######################
### INSTALL PEGASUS ###
#######################
wget -O - http://download.pegasus.isi.edu/pegasus/gpg.txt | sudo apt-key add -
echo 'deb [arch=amd64] http://download.pegasus.isi.edu/pegasus/ubuntu bionic main' | sudo tee /etc/apt/sources.list.d/pegasus.list
apt-get update && apt-get install -y pegasus

##########################
### INSTALL SINGULARITY ##
##########################

apt-get update && sudo apt-get install -y build-essential \
    uuid-dev \
    libgpgme-dev \
    squashfs-tools \
    libseccomp-dev \
    wget \
    pkg-config \
    git \
    cryptsetup-bin

export VERSION=1.16.2 OS=linux ARCH=amd64 && \
    wget https://dl.google.com/go/go$VERSION.$OS-$ARCH.tar.gz && \
    sudo tar -C /usr/local -xzvf go$VERSION.$OS-$ARCH.tar.gz && \
    rm go$VERSION.$OS-$ARCH.tar.gz

echo 'export GOPATH=${HOME}/go' >> ~/.bashrc
echo 'export PATH=/usr/local/go/bin:${PATH}:${GOPATH}/bin' >> ~/.bashrc

export GOPATH=${HOME}/go >> ~/.bashrc
export PATH=/usr/local/go/bin:${PATH}:${GOPATH}/bin >> ~/.bashrc

export VERSION=3.7.4 && # adjust this as necessary \
    wget https://github.com/hpcng/singularity/releases/download/v${VERSION}/singularity-${VERSION}.tar.gz && \
    tar -xzf singularity-${VERSION}.tar.gz && \
    rm singularity-${VERSION}.tar.gz && \
    cd singularity

./mconfig && \
    make -C ./builddir && \
    make -C ./builddir install

##########################
### INSTALL DOCKER      ##
##########################
cd
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -


apt-key fingerprint 0EBFCD88

add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io


#groupadd docker
usermod -aG docker condor

systemctl enable docker
systemctl restart docker

############################
### INSTALL NVIDIA DOCKER ##
############################
distribution=$(. /etc/os-release;echo $ID$VERSION_ID) \
   && curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add - \
   && curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list

apt-get update && apt-get install -y nvidia-docker2
systemctl restart docker

############################
### SETUP PANORAMA USER ####
############################
cd
useradd -s /bin/bash -d /home/panorama -m -G docker panorama

echo "panorama     ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

mkdir /home/panorama/.ssh
chmod -R 700 /home/panorama/.ssh
echo "SSH_PUBLIC_KEY" >> /home/panorama/.ssh/authorized_keys
chmod 600 /home/panorama/.ssh/authorized_keys
chown -R panorama:panorama /home/panorama/.ssh

echo 'export GOPATH=${HOME}/go' >> /home/panorama/.bashrc
echo 'export PATH=/usr/local/go/bin:${PATH}:${GOPATH}/bin' >> /home/panorama/.bashrc

#### Add http userdir for user panorama #####
mkdir /home/panorama/public_html
chmod -R 755 /home/panorama/public_html
chown -R panorama:panorama /home/panorama/public_html
sed -i 's/.*UserDir disabled.*/\tUserDir disabled root\n\tUserDir enabled panorama/g' /etc/apache2/mods-available/userdir.conf

systemctl restart apache2

