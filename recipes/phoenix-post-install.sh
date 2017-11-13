#!/bin/bash

getZeppelinHost () {
       	ZEPPELIN_HOST=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/ZEPPELIN/components/ZEPPELIN_MASTER |grep "host_name"|grep -Po ': "([a-zA-Z0-9\-_!?.]+)'|grep -Po '([a-zA-Z0-9\-_!?.]+)')
       	
       	echo $ZEPPELIN_HOST
}

export ROOT_PATH=~

echo "*********************************ROOT PATH IS: $ROOT_PATH"

export AMBARI_HOST=$(hostname -f)
echo "*********************************AMABRI HOST IS: $AMBARI_HOST"

export CLUSTER_NAME=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters |grep cluster_name|grep -Po ': "(.+)'|grep -Po '[a-zA-Z0-9\-_!?.]+')

if [[ -z $CLUSTER_NAME ]]; then
        echo "Could not connect to Ambari Server. Please run the install script on the same host where Ambari Server is installed."
        exit 0
else
       	echo "*********************************CLUSTER NAME IS: $CLUSTER_NAME"
fi

export HADOOP_USER_NAME=hdfs
echo "*********************************HADOOP_USER_NAME set to HDFS"

javac -d .  $ROOT_PATH/CloudBreakArtifacts/recipes/PHOENIX_DEMO/src/main/java/com/hortonworks/DataGen.java
java com/hortonworks/DataGen /tmp 100000000
hadoop fs -put /tmp/aum.csv /tmp/aum.csv

$ROOT_PATH/CloudBreakArtifacts/recipes/PHOENIX_DEMO/configureZeppelin.py $(getZeppelinHost) 9995

exit 0