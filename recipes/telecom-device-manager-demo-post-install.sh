#!/bin/bash
exec > >(tee -i demoInstall.log)
exec 2>&1
echo "*********************************Install Device Manager Demo"
https://github.com/vakshorton/DeviceManagerDemo
cd DeviceManagerDemo
sed -r -i 's;\{\{jdk64_home\}\};/usr/jdk64;' Nifi/config/nifi-env.json
./install.sh
./startDemoServices.sh
./startSimulation.sh

exit 0