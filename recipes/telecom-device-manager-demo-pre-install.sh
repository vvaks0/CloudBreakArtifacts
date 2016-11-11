#!/bin/bash
exec > >(tee -i preProvisioning.log)
exec 2>&1
echo "*********************************Install and Enable Open JDK 8"
yum install -y wget
yum install -y java-1.8.0-openjdk-devel
echo "*********************************Install and Enable Oracle JDK 8"
wget http://public-repo-1.hortonworks.com/ARTIFACTS/jdk-8u77-linux-x64.tar.gz
tar -vxzf jdk-8u77-linux-x64.tar.gz -C /usr
mv /usr/jdk1.8.0_77 /usr/jdk64
alternatives --install /usr/bin/java java /usr/jdk64/bin/java 3
alternatives --install /usr/bin/javac javac /usr/jdk64/bin/javac 3
alternatives --install /usr/bin/jar jar /usr/jdk64/bin/jar 3
export JAVA_HOME=/usr/jdk64
echo "export JAVA_HOME=/usr/jdk64" >> /etc/bashrc

exit 0