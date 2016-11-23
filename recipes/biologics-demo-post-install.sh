#!/bin/bash
exec > >(tee -i demoInstall.log)
exec 2>&1
echo "*********************************Install Credit Fraud Demo"
git clone https://github.com/vakshorton/BiologicsManufacturingDemo
cd RetailStoreMonitor
sed -r -i 's;\{\{jdk64_home\}\};/usr/jdk64;' Nifi/config/nifi-env.json
./install.sh
./startDemoServices.sh
./startSimulation.sh

exit 0