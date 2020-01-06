#!/bin/bash

# this script should run as root

yum -y update
yum install -y gcc gcc-c++ make libarchive-devel wget
yum install -y https://centos7.iuscommunity.org/ius-release.rpm
yum install -y python36
yum -y update

wget http://download-ib01.fedoraproject.org/pub/epel/7/x86_64/Packages/b/boost169-python2-1.69.0-2.el7.x86_64.rpm
wget http://download-ib01.fedoraproject.org/pub/epel/7/x86_64/Packages/b/boost169-python3-1.69.0-2.el7.x86_64.rpm
rpm -Uvh boost169-*.rpm

######################
### INSTALL CONDOR ###
######################

rpm --import https://research.cs.wisc.edu/htcondor/yum/RPM-GPG-KEY-HTCondor
wget https://research.cs.wisc.edu/htcondor/yum/repo.d/htcondor-development-rhel7.repo -O /etc/yum.repos.d/htcondor-development-rhel7.repo
yum install -y condor-all

cat << EOF > /etc/condor/config.d/50-main.config
DAEMON_LIST = MASTER, COLLECTOR, NEGOTIATOR, SCHEDD
CONDOR_HOST=`hostname`
USE_SHARED_PORT = TRUE
NETWORK_INTERFACE=
# the nodes have shared filesystem
UID_DOMAIN = \$(CONDOR_HOST)
TRUST_UID_DOMAIN = TRUE
FILESYSTEM_DOMAIN = \$(FULL_HOSTNAME)
# Schedd and Negotiator run more often
NEGOTIATOR_INTERVAL=45
NEGOTIATOR_UPDATE_AFTER_CYCLE= TRUE
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
ALLOW_READ = *
ALLOW_WRITE = *
EOF

condor_store_cred -f /etc/condor/pool_password -p c454_c0nd0r_p00l

systemctl enable condor
systemctl restart condor

##########################
### INSTALL SINGULARITY ##
##########################

SINGULARITY_VERSION=2.6.0
parent_dir=`pwd`
wget https://github.com/sylabs/singularity/releases/download/${SINGULARITY_VERSION}/singularity-${SINGULARITY_VERSION}.tar.gz
tar xvf singularity-${SINGULARITY_VERSION}.tar.gz
cd singularity-${SINGULARITY_VERSION}
./configure --prefix=/usr/local
make && make install
cd $parent_dir
rm -r singularity-${SINGULARITY_VERSION}
rm singularity-${SINGULARITY_VERSION}.tar.gz

##########################
### INSTALL DOCKER      ##
##########################
yum install -y yum-utils \
    device-mapper-persistent-data \
    lvm2

yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo

yum install -y docker-ce docker-ce-cli containerd.io

groupadd docker
usermod -aG docker condor

systemctl enable docker
systemctl restart docker

