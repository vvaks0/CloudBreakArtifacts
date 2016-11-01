#!/bin/bash
exec > >(tee -i demoInstall.log)
exec 2>&1
echo "*********************************Create /user/root HDFS folder for Slider..."
sudo -u hdfs hadoop fs -mkdir /user/root/
sudo -u hdfs hadoop fs -chown root:hdfs /user/root/
echo "*********************************Install Credit Fraud Demo"
git clone https://github.com/vakshorton/RetailStoreMonitor
cd RetailStoreMonitor
sed -r -i 's;\{\{jdk64_home\}\};/usr/jdk64;' Nifi/config/nifi-env.json
./install.sh
./startDemoServices.sh
./startSimulation.sh