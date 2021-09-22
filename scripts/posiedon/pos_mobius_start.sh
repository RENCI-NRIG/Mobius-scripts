#!/bin/bash
if [ $# -ne 2 ]; then
    echo "Required arguments [WORKFLOWID] [family] not provided!"
    exit 4
fi

WORKFLOWID=$1
RTOKEN="$1read"
WTOKEN="$1write"
FAMILY=$2

echo $WORKFLOWID
echo $RTOKEN
echo $WTOKEN
echo $FAMILY

yum install -y epel-release
yum -y update
yum install -y git
yum install -y python-pip
yum install -y wget python-devel gcc 
yum groupinstall "Development Tools" -y
yum install openssl-devel libffi-devel bzip2-devel -y
wget https://www.python.org/ftp/python/3.9.5/Python-3.9.5.tgz
tar xvf Python-3.9.5.tgz
cd Python-3.9*/
./configure --enable-optimizations
make altinstall
cd ..


mkdir -p /var/private/ssl

git clone https://github.com/RENCI-NRIG/host-key-tools.git /root/host-key-tools 
cd /root/host-key-tools/hostkey-py/ 
pip3.9 install -r requirements.txt
python3.9 setup.py install 

cp /root/host-key-tools/host-key-tools.service /usr/lib/systemd/system 
sed -i "s/ExecStart=.*/ExecStart=\/usr\/local\/bin\/hostkeyd start -c https:\/\/comet-hn1.exogeni.net:8111\/ -s $WORKFLOWID -r $RTOKEN -w $WTOKEN -f $FAMILY -k dynamo-broker1.exogeni.net:9093 -t mobius-promeithus -p False/g" /usr/lib/systemd/system/host-key-tools.service 

systemctl enable host-key-tools.service  

cd /root/ 

wget  http://geni-images.renci.org/images/kthare10/certs/new/snakeoil-ca-1.crt -O /var/private/ssl/ca.crt
wget  http://geni-images.renci.org/images/kthare10/certs/new/kafkacat1-ca1-signed.pem  -O /var/private/ssl/client.pem
wget  http://geni-images.renci.org/images/kthare10/certs/new/kafkacat1.client.key -O /var/private/ssl/key.pem

iptables -A INPUT -s 152.54.2.162/32 -j ACCEPT
systemctl start host-key-tools.service  
wget https://github.com/prometheus/node_exporter/releases/download/v1.0.0-rc.0/node_exporter-1.0.0-rc.0.linux-amd64.tar.gz 
tar -zxvf node_exporter-1.0.0-rc.0.linux-amd64.tar.gz -C /opt

/opt/node_exporter-1.0.0-rc.0.linux-amd64/node_exporter > /var/log/node_exporter.log 2>&1 &
