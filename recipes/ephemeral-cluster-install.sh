#!/bin/bash

installUtils () {
	echo "*********************************Installing WGET..."
	yum install -y wget
	
	echo "*********************************Installing Maven..."
	wget http://repos.fedorapeople.org/repos/dchen/apache-maven/epel-apache-maven.repo -O 	/etc/yum.repos.d/epel-apache-maven.repo
	if [ $(cat /etc/system-release|grep -Po Amazon) == Amazon ]; then
		sed -i s/\$releasever/6/g /etc/yum.repos.d/epel-apache-maven.repo
	fi
	yum install -y apache-maven
	if [ $(cat /etc/system-release|grep -Po Amazon) == Amazon ]; then
		alternatives --install /usr/bin/java java /usr/lib/jvm/jre-1.8.0-openjdk.x86_64/bin/java 20000
		alternatives --install /usr/bin/javac javac /usr/lib/jvm/jre-1.8.0-openjdk.x86_64/bin/javac 20000
		alternatives --install /usr/bin/jar jar /usr/lib/jvm/jre-1.8.0-openjdk.x86_64/bin/jar 20000
		alternatives --auto java
		alternatives --auto javac
		alternatives --auto jar
		ln -s /usr/lib/jvm/java-1.8.0 /usr/lib/jvm/java
	fi
	
	echo "*********************************Installing GIT..."
	yum install -y git
	
	echo "*********************************Installing Docker..."
	echo " 				  *****************Installing Docker via Yum..."
		yum install -y docker
	
	echo " 				  *****************Configuring Docker Permissions..."
	groupadd docker
	gpasswd -a yarn docker
	echo " 				  *****************Registering Docker to Start on Boot..."
	service docker start
	chkconfig --add docker
	chkconfig docker on
}

waitForAmbari () {
       	# Wait for Ambari
       	LOOPESCAPE="false"
       	until [ "$LOOPESCAPE" == true ]; do
        TASKSTATUS=$(curl -u admin:admin -I -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME | grep -Po 'OK')
        if [ "$TASKSTATUS" == OK ]; then
                LOOPESCAPE="true"
                TASKSTATUS="READY"
        else
               	AUTHSTATUS=$(curl -u admin:admin -I -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME | grep HTTP | grep -Po '( [0-9]+)'| grep -Po '([0-9]+)')
               	if [ "$AUTHSTATUS" == 403 ]; then
               	echo "THE AMBARI PASSWORD IS NOT SET TO: admin"
               	echo "RUN COMMAND: ambari-admin-password-reset, SET PASSWORD: admin"
               	exit 403
               	else
                TASKSTATUS="PENDING"
               	fi
       	fi
       	echo "Waiting for Ambari..."
        echo "Ambari Status... " $TASKSTATUS
        sleep 2
       	done
}

serviceExists () {
       	SERVICE=$1
       	SERVICE_STATUS=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/$SERVICE | grep '"status" : ' | grep -Po '([0-9]+)')

       	if [ "$SERVICE_STATUS" == 404 ]; then
       		echo 0
       	else
       		echo 1
       	fi
}

getServiceStatus () {
       	SERVICE=$1
       	SERVICE_STATUS=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/$SERVICE | grep '"state" :' | grep -Po '([A-Z]+)')

       	echo $SERVICE_STATUS
}

getComponentStatus () {
       	SERVICE=$1
       	COMPONENT=$2
       	COMPONENT_STATUS=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/$SERVICE/components/$COMPONENT | grep '"state" :' | grep -Po '([A-Z]+)')

       	echo $COMPONENT_STATUS
}

startServiceIfReady () {
	SERVICE=$1
	SERVICE_STATUS=$(getServiceStatus $SERVICE)
	echo "*********************************Checking $SERVICE status..."
	if ! [[ $SERVICE_STATUS == STARTED || $SERVICE_STATUS == INSTALLED ]]; then
       	echo "*********************************$SERVICE is in a transitional state, waiting..."
       	waitForService $SERVICE
       	echo "*********************************$SERVICE has entered a ready state..."
	elif [[ $SERVICE_STATUS == INSTALLED ]]; then
       	startService $SERVICE
	else
       	echo "*********************************$SERVICE Service Started..."
	fi
}

getComponentStatus () {
       	SERVICE=$1
       	COMPONENT=$2
       	COMPONENT_STATUS=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/$SERVICE/components/$COMPONENT | grep '"state" :' | grep -Po '([A-Z]+)')

       	echo $COMPONENT_STATUS
}

getNameNodeHost () {
        NAMENODE_HOST=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/HDFS/components/NAMENODE|grep "host_name"|grep -Po ': "([a-zA-Z0-9\-_!?.]+)'|grep -Po '([a-zA-Z0-9\-_!?.]+)')

        echo $NAMENODE_HOST
}

getHiveServerHost () {
        HIVESERVER_HOST=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/HIVE/components/HIVE_SERVER|grep "host_name"|grep -Po ': "([a-zA-Z0-9\-_!?.]+)'|grep -Po '([a-zA-Z0-9\-_!?.]+)')

        echo $HIVESERVER_HOST
}

getHiveMetaStoreHost () {
        HIVE_METASTORE_HOST=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/HIVE/components/HIVE_METASTORE|grep "host_name"|grep -Po ': "([a-zA-Z0-9\-_!?.]+)'|grep -Po '([a-zA-Z0-9\-_!?.]+)')

        echo $HIVE_METASTORE_HOST
}

getHiveMySQLHost () {
        HIVE_MYSQL_HOST=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/HIVE/components/MYSQL_SERVER|grep "host_name"|grep -Po ': "([a-zA-Z0-9\-_!?.]+)'|grep -Po '([a-zA-Z0-9\-_!?.]+)')

        echo $HIVE_MYSQL_HOST
}

getHiveInteractiveServerHost () {
        HIVESERVER_INTERACTIVE_HOST=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/HIVE/components/HIVE_SERVER_INTERACTIVE|grep "host_name"|grep -Po ': "([a-zA-Z0-9\-_!?.]+)'|grep -Po '([a-zA-Z0-9\-_!?.]+)')

        echo $HIVESERVER_INTERACTIVE_HOST
}

getRangerHost () {
        RANGER_HOST=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/RANGER/components/RANGER_ADMIN|grep "host_name"|grep -Po ': "([a-zA-Z0-9\-_!?.]+)'|grep -Po '([a-zA-Z0-9\-_!?.]+)')

        echo $RANGER_HOST
}

getZKHost () {
       	ZK_HOST=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/ZOOKEEPER/components/ZOOKEEPER_SERVER|grep "host_name"|grep -Po ': "([a-zA-Z0-9\-_!?.]+)'|grep -Po '([a-zA-Z0-9\-_!?.]+)'|head -1)
       	
       	echo $ZK_HOST
}

getKafkaBroker () {
       	KAFKA_BROKER=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/KAFKA/components/KAFKA_BROKER |grep "host_name"|grep -Po ': "([a-zA-Z0-9\-_!?.]+)'|grep -Po '([a-zA-Z0-9\-_!?.]+)')
       	
       	echo $KAFKA_BROKER
}

getAtlasHost () {
       	ATLAS_HOST=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/ATLAS/components/ATLAS_SERVER |grep "host_name"|grep -Po ': "([a-zA-Z0-9\-_!?.]+)'|grep -Po '([a-zA-Z0-9\-_!?.]+)')
       	
       	echo $ATLAS_HOST
}

getNifiHost () {
       	NIFI_HOST=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/NIFI/components/NIFI_MASTER|grep "host_name"|grep -Po ': "([a-zA-Z0-9\-_!?.]+)'|grep -Po '([a-zA-Z0-9\-_!?.]+)')

       	echo $NIFI_HOST
}

waitForService () {
       	# Ensure that Service is not in a transitional state
       	SERVICE=$1
       	SERVICE_STATUS=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/$SERVICE | grep '"state" :' | grep -Po '([A-Z]+)')
       	sleep 2
       	echo "$SERVICE STATUS: $SERVICE_STATUS"
       	LOOPESCAPE="false"
       	if ! [[ "$SERVICE_STATUS" == STARTED || "$SERVICE_STATUS" == INSTALLED ]]; then
        until [ "$LOOPESCAPE" == true ]; do
                SERVICE_STATUS=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/$SERVICE | grep '"state" :' | grep -Po '([A-Z]+)')
            if [[ "$SERVICE_STATUS" == STARTED || "$SERVICE_STATUS" == INSTALLED ]]; then
                LOOPESCAPE="true"
            fi
            echo "*********************************$SERVICE Status: $SERVICE_STATUS"
            sleep 2
        done
       	fi
}

waitForServiceToStart () {
       	# Ensure that Service is not in a transitional state
       	SERVICE=$1
       	SERVICE_STATUS=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/$SERVICE | grep '"state" :' | grep -Po '([A-Z]+)')
       	sleep 2
       	echo "$SERVICE STATUS: $SERVICE_STATUS"
       	LOOPESCAPE="false"
       	if ! [[ "$SERVICE_STATUS" == STARTED ]]; then
        	until [ "$LOOPESCAPE" == true ]; do
                SERVICE_STATUS=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/$SERVICE | grep '"state" :' | grep -Po '([A-Z]+)')
            if [[ "$SERVICE_STATUS" == STARTED ]]; then
                LOOPESCAPE="true"
            fi
            echo "*********************************$SERVICE Status: $SERVICE_STATUS"
            sleep 2
        done
       	fi
}

stopService () {
       	SERVICE=$1
       	SERVICE_STATUS=$(getServiceStatus $SERVICE)
       	echo "*********************************Stopping Service $SERVICE ..."
       	if [ "$SERVICE_STATUS" == STARTED ]; then
        TASKID=$(curl -u admin:admin -H "X-Requested-By:ambari" -i -X PUT -d "{\"RequestInfo\": {\"context\": \"Stop $SERVICE\"}, \"ServiceInfo\": {\"maintenance_state\" : \"OFF\", \"state\": \"INSTALLED\"}}" http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/$SERVICE | grep "id" | grep -Po '([0-9]+)')

        echo "*********************************Stop $SERVICE TaskID $TASKID"
        sleep 2
        LOOPESCAPE="false"
        until [ "$LOOPESCAPE" == true ]; do
            TASKSTATUS=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/requests/$TASKID | grep "request_status" | grep -Po '([A-Z]+)')
            if [ "$TASKSTATUS" == COMPLETED ]; then
                LOOPESCAPE="true"
            fi
            echo "*********************************Stop $SERVICE Task Status $TASKSTATUS"
            sleep 2
        done
        echo "*********************************$SERVICE Service Stopped..."
       	elif [ "$SERVICE_STATUS" == INSTALLED ]; then
       	echo "*********************************$SERVICE Service Stopped..."
       	fi
}

startService (){
       	SERVICE=$1
       	SERVICE_STATUS=$(getServiceStatus $SERVICE)
       	echo "*********************************Starting Service $SERVICE ..."
       	if [ "$SERVICE_STATUS" == INSTALLED ]; then
        TASKID=$(curl -u admin:admin -H "X-Requested-By:ambari" -i -X PUT -d "{\"RequestInfo\": {\"context\": \"Start $SERVICE\"}, \"ServiceInfo\": {\"maintenance_state\" : \"OFF\", \"state\": \"STARTED\"}}" http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/$SERVICE | grep "id" | grep -Po '([0-9]+)')

        echo "*********************************Start $SERVICE TaskID $TASKID"
        sleep 2
        LOOPESCAPE="false"
        until [ "$LOOPESCAPE" == true ]; do
            TASKSTATUS=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/requests/$TASKID | grep "request_status" | grep -Po '([A-Z]+)')
            if [[ "$TASKSTATUS" == COMPLETED || "$TASKSTATUS" == FAILED ]]; then
                LOOPESCAPE="true"
            fi
            echo "*********************************Start $SERVICE Task Status $TASKSTATUS"
            sleep 2
        done
       	elif [ "$SERVICE_STATUS" == STARTED ]; then
       	echo "*********************************$SERVICE Service Started..."
       	fi
}

startServiceAndComplete (){
       	SERVICE=$1
       	SERVICE_STATUS=$(getServiceStatus $SERVICE)
       	echo "*********************************Starting Service $SERVICE ..."
       	if [ "$SERVICE_STATUS" == INSTALLED ]; then
        TASKID=$(curl -u admin:admin -H "X-Requested-By:ambari" -i -X PUT -d "{\"RequestInfo\": {\"context\": \"INSTALL COMPLETE\"}, \"ServiceInfo\": {\"maintenance_state\" : \"OFF\", \"state\": \"STARTED\"}}" http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/$SERVICE | grep "id" | grep -Po '([0-9]+)')

        echo "*********************************Start $SERVICE TaskID $TASKID"
        sleep 2
        LOOPESCAPE="false"
        until [ "$LOOPESCAPE" == true ]; do
            TASKSTATUS=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/requests/$TASKID | grep "request_status" | grep -Po '([A-Z]+)')
            if [[ "$TASKSTATUS" == COMPLETED || "$TASKSTATUS" == FAILED ]]; then
                LOOPESCAPE="true"
            fi
            echo "*********************************Start $SERVICE Task Status $TASKSTATUS"
            sleep 2
        done
       	elif [ "$SERVICE_STATUS" == STARTED ]; then
       	echo "*********************************$SERVICE Service Started..."
       	fi
}

exec > >(tee -i /root/historian-install.log)
exec 2>&1

export ROOT_PATH=~
echo "*********************************ROOT PATH IS: $ROOT_PATH"

AMBARI_HOST=$(cat /etc/ambari-agent/conf/ambari-agent.ini| grep hostname= |grep -Po '([0-9.]+)')
echo "*********************************AMABRI HOST IS: $AMBARI_HOST"

export CLUSTER_NAME=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters |grep cluster_name|grep -Po ': "(.+)'|grep -Po '[a-zA-Z0-9\-_!?.]+')

if [[ -z $CLUSTER_NAME ]]; then
        echo "Could not connect to Ambari Server. Please run the install script on the same host where Ambari Server is installed."
        exit 0
else
       	echo "*********************************CLUSTER NAME IS: $CLUSTER_NAME"
fi

waitForServiceToStart YARN

waitForServiceToStart HDFS

waitForServiceToStart ATLAS

waitForServiceToStart HIVE

waitForServiceToStart ZOOKEEPER


export VERSION=`hdp-select status hadoop-client | sed 's/hadoop-client - \([0-9]\.[0-9]\).*/\1/'`
export INTVERSION=$(echo $VERSION*10 | bc | grep -Po '([0-9][0-9])')
echo "*********************************HDP VERSION IS: $VERSION"

echo "*********************************CHANGE AMBARI HOST TO SHARED SERVICES CLUSTER"
export AMBARI_HOST=$1
export CLUSTER_NAME=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters |grep cluster_name|grep -Po ': "(.+)'|grep -Po '[a-zA-Z0-9\-_!?.]+')
echo "*********************************$AMBARI_HOST : $CLUSTER_NAME"

export HADOOP_USER_NAME=hdfs
echo "*********************************HADOOP_USER_NAME set to HDFS"
hadoop fs -mkdir /user/admin
hadoop fs -chown admin:hdfs /user/admin

export S3_TARGET_BUCKET=$2
export SHARED_HIVE_REPO=$3

export SHARED_CLUSTER_NAME=$CLUSTER_NAME
export SHARED_ZK_HOST=$(getZKHost)
export SHARED_NAMENODE_HOST=$(getNameNodeHost)
export SHARED_KAFKA_BROKER=$(getKafkaBroker)
export SHARED_KAFKA_PORT="6667"
export SHARED_ATLAS_HOST=$(getAtlasHost)
export SHARED_ATLAS_PORT="21000"
export SHARED_RANGER_HOST=$(getRangerHost)
export SHARED_RANGER_PORT="6080"
export SHARED_HIVESERVER_HOST=$(getHiveServerHost)
export SHARED_HIVE_MYSQL_HOST=$(getHiveMySQLHost)
export SHARED_HIVE_METASTORE_HOST=$(getHiveMetaStoreHost)
export SHARED_HIVE_METASTORE_PORT="9083"
export SHARED_HIVESERVER_INTERACTIVE_HOST=$(getHiveInteractiveServerHost)

echo "SHARED_ZK_HOST" $SHARED_ZK_HOST
echo "SHARED_KAFKA_BROKER" $SHARED_KAFKA_BROKER
echo "SHARED_KAFKA_PORT" $SHARED_KAFKA_PORT
echo "SHARED_ATLAS_HOST" $SHARED_ATLAS_HOST
echo "SHARED_RANGER_HOST" $SHARED_RANGER_HOST
echo "SHARED_RANGER_PORT" $SHARED_RANGER_PORT
echo "SHARED_HIVESERVER_HOST" $SHARED_HIVESERVER_HOST
echo "SHARED_HIVE_MYSQL_HOST" $SHARED_HIVE_MYSQL_HOST
echo "SHARED_HIVE_METASTORE_HOST" $SHARED_HIVE_METASTORE_HOST
echo "SHARED_HIVE_METASTORE_PORT" $SHARED_HIVE_METASTORE_PORT
echo "SHARED_HIVESERVER_INTERACTIVE_HOST" $SHARED_HIVESERVER_INTERACTIVE_HOST

echo "**********Install and configure Ranger Hive Plugin"
echo "**********Modify configuration files"
CONFIG_DIR=$ROOT_PATH/CloudBreakArtifacts/recipes/DATA_PLANE_CLIENT/package/configuration/
    
sed -r -i 's;\{\{ZK_HOST\}\};'$SHARED_ZK_HOST';' $CONFIG_DIR/ranger-hive-audit.xml
sed -r -i 's;\{\{NAMENODE_HOST\}\};'$SHARED_NAMENODE_HOST';' $CONFIG_DIR/ranger-hive-audit.xml
sed -r -i 's;\{\{RANGER_URL\}\};http://'$SHARED_RANGER_HOST':'$SHARED_RANGER_PORT';' $CONFIG_DIR/ranger-hive-security.xml
sed -r -i 's;\{\{REPO_NAME\}\};'$SHARED_HIVE_REPO';' $CONFIG_DIR/ranger-hive-security.xml

sed -r -i 's;\{\{ZK_HOST\}\};'$SHARED_ZK_HOST';' $CONFIG_DIR/ranger-hive-audit
sed -r -i 's;\{\{NAMENODE_HOST\}\};'$SHARED_NAMENODE_HOST';' $CONFIG_DIR/ranger-hive-audit
sed -r -i 's;\{\{RANGER_URL\}\};http://'$SHARED_RANGER_HOST':'$SHARED_RANGER_PORT';' $CONFIG_DIR/ranger-hive-security
sed -r -i 's;\{\{REPO_NAME\}\};'$SHARED_HIVE_REPO';' $CONFIG_DIR/ranger-hive-security
    
echo "**********Copying configuration files to Hive Server conf directory"
HIVE_CONFIG_DIR=/usr/hdp/current/hive-server2/conf/conf.server/
cp $CONFIG_DIR/* $HIVE_CONFIG_DIR
    
HIVE_CONFIG_DIR=/usr/hdp/current/hive-server2-hive2/conf/conf.server/
cp $CONFIG_DIR/* $HIVE_CONFIG_DIR


echo "*********************************CHANGE AMBARI HOST TO LOCAL CLUSTER"
AMBARI_HOST=$(cat /etc/ambari-agent/conf/ambari-agent.ini| grep hostname= |grep -Po '([0-9.]+)')
export CLUSTER_NAME=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters |grep cluster_name|grep -Po ': "(.+)'|grep -Po '[a-zA-Z0-9\-_!?.]+')
echo "*********************************$AMBARI_HOST : $CLUSTER_NAME"


echo "*********************************CREATE HIVE AMBARI USER"
curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST -d '{"Users/user_name":"hive","Users/password":"hive","Users/active":true,"Users/admin":false}' http://$AMBARI_HOST:8080/api/v1/users

echo "*********************************GRANT HIVE AMBARI USER HIVE VIEW 2.0 ACCESS"
curl -u admin:admin -H "Content-Type:plain/text" -H "X-Requested-By:ambari" -i -X PUT -d '[{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"hive","principal_type":"USER"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"CLUSTER.ADMINISTRATOR","principal_type":"ROLE"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"CLUSTER.OPERATOR","principal_type":"ROLE"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"SERVICE.OPERATOR","principal_type":"ROLE"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"SERVICE.ADMINISTRATOR","principal_type":"ROLE"}},{"PrivilegeInfo":{"permission_name":"VIEW.USER","principal_name":"CLUSTER.USER","principal_type":"ROLE"}}]' http://$AMBARI_HOST:8080/api/v1/views/HIVE/versions/2.0.0/instances/AUTO_HIVE20_INSTANCE/privileges

echo "**********Setting Hive Plugin configuration"
CONFIG_HELPER=/var/lib/ambari-server/resources/scripts/configs.sh

$CONFIG_HELPER set $AMBARI_HOST $CLUSTER_NAME hive-site hive.security.authorization.enabled true

$CONFIG_HELPER set $AMBARI_HOST $CLUSTER_NAME hive-site hive.conf.restricted.list hive.security.authorization.enabled,hive.security.authorization.manager,hive.security.authenticator.manager

$CONFIG_HELPER set $AMBARI_HOST $CLUSTER_NAME hiveserver2-site hive.security.authorization.enabled true

$CONFIG_HELPER set $AMBARI_HOST $CLUSTER_NAME hiveserver2-site hive.security.authorization.manager org.apache.ranger.authorization.hive.authorizer.RangerHiveAuthorizerFactory

$CONFIG_HELPER set $AMBARI_HOST $CLUSTER_NAME hiveserver2-site hive.security.authenticator.manager org.apache.hadoop.hive.ql.security.SessionStateUserAuthenticator
    
$CONFIG_HELPER set $AMBARI_HOST $CLUSTER_NAME ranger-hive-audit $CONFIG_DIR/ranger-hive-audit

$CONFIG_HELPER set $AMBARI_HOST $CLUSTER_NAME ranger-hive-plugin-properties $CONFIG_DIR/ranger-hive-plugin-properties

$CONFIG_HELPER set $AMBARI_HOST $CLUSTER_NAME ranger-hive-policymgr-ssl $CONFIG_DIR/ranger-hive-policymgr-ssl

$CONFIG_HELPER set $AMBARI_HOST $CLUSTER_NAME ranger-hive-security $CONFIG_DIR/ranger-hive-security

echo "**********Setting Hive Atlas Client Configuration..."
$CONFIG_HELPER set $AMBARI_HOST $CLUSTER_NAME hive-site "atlas.rest.address" "$SHARED_ATLAS:$SHARED_ATLAS_PORT"

$CONFIG_HELPER set $AMBARI_HOST $CLUSTER_NAME hive-site "atlas.cluster.name" $SHARED_CLUSTER_NAME

$CONFIG_HELPER set $AMBARI_HOST $CLUSTER_NAME application-properties "atlas.cluster.name" $SHARED_CLUSTER_NAME

$CONFIG_HELPER set $AMBARI_HOST $CLUSTER_NAME hive-atlas-application.properties "atlas.kafka.bootstrap.servers" "$SHARED_KAFKA_BROKER:$SHARED_KAFKA_PORT"

$CONFIG_HELPER set $AMBARI_HOST $CLUSTER_NAME hive-atlas-application.properties "atlas.kafka.zookeeper.connect" "$SHARED_KAFKA_BROKER:$SHARED_KAFKA_PORT"

echo "**********Setting Hive Meta Store Configuration..."
$CONFIG_HELPER set $AMBARI_HOST $CLUSTER_NAME hive-site "javax.jdo.option.ConnectionURL" "jdbc:mysql://$SHARED_HIVE_MYSQL_HOST/hive?createDatabaseIfNotExist=true"

$CONFIG_HELPER set $AMBARI_HOST $CLUSTER_NAME hive-site "javax.jdo.option.ConnectionPassword" "hive"

$CONFIG_HELPER set $AMBARI_HOST $CLUSTER_NAME hive-site "hive.metastore.uris" "thrift://$SHARED_HIVE_METASTORE_HOST:$SHARED_HIVE_METASTORE_PORT"

#if params.spark_exists_code == '200':
#    $CONFIG_HELPER set $AMBARI_HOST $CLUSTER_NAME spark-hive-site-override "thrift://$SHARED_HIVE_METASTORE_HOST:9083"

echo "**********Configuring Data Storage and Keys..."
$CONFIG_HELPER set $AMBARI_HOST $CLUSTER_NAME hive-site "hive.metastore.warehouse.dir" "$S3_TARGET_BUCKET"

sleep 10
echo "**********Restarting Services with Stale Configs..."
stopService HIVE
sleep 2
startService HIVE
sleep 2
stopService ATLAS
sleep 2
startServiceAndComplete ATLAS

exit 0