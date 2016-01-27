#!/bin/bash

set -e
set -x

SCRIPTS=`dirname "$(readlink -f "$0")"`
MHN_HOME=$SCRIPTS/..

if [ -f /etc/debian_version ]; then
    OS=Debian  # XXX or Ubuntu??
    INSTALLER='apt-get'
    REPOPACKAGES='libffi-dev build-essential python-pip python-dev git libssl-dev supervisor'

    PYTHON=`which python`
    PIP=`which pip`
    $PIP install virtualenv
    VIRTUALENV=`which virtualenv`

elif [ -f /etc/redhat-release ]; then
    OS=RHEL
    INSTALLER='yum'
    REPOPACKAGES='epel-release libffi-devel libssl-devel shadowsocks-libev-devel'

    #yum install -y yum-utils
    yum-config-manager --add-repo=https://copr.fedoraproject.org/coprs/librehat/shadowsocks/repo/epel-6/librehat-shadowsocks-epel-6.repo
    yum update -y

    if  [ ! -f /usr/local/bin/python2.7 ]; then
        $SCRIPTS/install_python2.7.sh
    fi

    #use python2.7
    PYTHON=/usr/local/bin/python2.7
    PIP=/usr/local/bin/pip2.7
    $PIP install virtualenv
    VIRTUALENV=/usr/local/bin/virtualenv

    #install supervisor from pip2.7
    $SCRIPTS/install_supervisord.sh

else
    echo -e "ERROR: Unknown OS\nExiting!"
    exit -1
fi

$INSTALLER -y update
$INSTALLER -y install $REPOPACKAGES
ldconfig /usr/local/lib/

bash install_mongo.sh

$PIP install virtualenv

cd /tmp
wget https://github.com/threatstream/hpfeeds/releases/download/libev-4.15/libev-4.15.tar.gz
tar zxvf libev-4.15.tar.gz 
cd libev-4.15
./configure && make && make install
ldconfig /usr/local/lib/


mkdir -p /opt
cd /opt
rm -rf /opt/hpfeeds
git clone https://github.com/threatstream/hpfeeds
chmod 755 -R hpfeeds
cd hpfeeds
$VIRTUALENV -p $PYTHON env
. env/bin/activate

pip install cffi
pip install pyopenssl==0.14
pip install pymongo
pip install -e git+https://github.com/rep/evnet.git#egg=evnet-dev
pip install .

mkdir -p /var/log/mhn
mkdir -p /etc/supervisor/
mkdir -p /etc/supervisor/conf.d


cat >> /etc/supervisor/conf.d/hpfeeds-broker.conf <<EOF 
[program:hpfeeds-broker]
command=/opt/hpfeeds/env/bin/python /opt/hpfeeds/broker/feedbroker.py
directory=/opt/hpfeeds
stdout_logfile=/var/log/mhn/hpfeeds-broker.log
stderr_logfile=/var/log/mhn/hpfeeds-broker.err
autostart=true
autorestart=true
startsecs=10
EOF

ldconfig /usr/local/lib/
supervisorctl update
