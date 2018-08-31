#!/bin/bash

wget http://repos.fedorapeople.org/repos/dchen/apache-maven/epel-apache-maven.repo -O /etc/yum.repos.d/epel-apache-maven.repo
sed -i s/\$releasever/6/g /etc/yum.repos.d/epel-apache-maven.repo
yum install -y apache-maven

git clone https://github.com/geomesa/geomesa-nifi.git
cd geomesa-nifi
mvn clean install
cp geomesa-nifi-nar/target/geomesa-nifi-nar-* /usr/hdf/current/nifi/lib/

mkdir /usr/share/geoserver
cd /usr/share/geoserver
wget http://sourceforge.net/projects/geoserver/files/GeoServer/2.13.2/geoserver-2.13.2-bin.zip
unzip geoserver-2.13.2-bin.zip
cd geoserver-2.13.2/bin
echo "export GEOSERVER_HOME=/usr/share/geoserver/geoserver-2.13.2" >> ~/.profile
. ~/.profile
#nohup ./startup.sh > geoserver.log &
