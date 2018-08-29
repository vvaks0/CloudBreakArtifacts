#!/bin/bash

cd /usr/dp/current/core/bin/
./dpdeploy.sh start
cd /usr/dss-app/current/apps/dss/bin/
./dssdeploy.sh start
cd /usr/dlm-app/current/apps/dlm/bin/
./dlmdeploy.sh start
cd ~