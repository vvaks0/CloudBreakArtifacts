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
	if [ $(cat /etc/system-release|grep -Po Amazon) == Amazon ]; then
		yum install -y docker
	else
		echo " 				  *****************Adding Docker Yum Repo..."
		tee /etc/yum.repos.d/docker.repo <<-'EOF'
		[dockerrepo]
		name=Docker Repository
		baseurl=https://yum.dockerproject.org/repo/main/centos/$releasever/
		enabled=1
		gpgcheck=1
		gpgkey=https://yum.dockerproject.org/gpg
		EOF
		rpm -iUvh http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
		yum install -y docker-io
	fi
	
	echo " 				  *****************Configuring Docker Permissions..."
	groupadd docker
	gpasswd -a yarn docker
	echo " 				  *****************Registering Docker to Start on Boot..."
	service docker start
	chkconfig --add docker
	chkconfig docker on
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
        TASKID=$(curl -u admin:admin -H "X-Requested-By:ambari" -i -X PUT -d '{"RequestInfo": {"context": "Stop $SERVICE"}, "ServiceInfo": {"maintenance_state" : "OFF", "state": "INSTALLED"}}' http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/$SERVICE | grep "id" | grep -Po '([0-9]+)')

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
        TASKID=$(curl -u admin:admin -H "X-Requested-By:ambari" -i -X PUT -d '{"RequestInfo": {"context": "Start $SERVICE" }, "ServiceInfo": {"maintenance_state" : "OFF", "state": "STARTED"}}' http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/$SERVICE | grep "id" | grep -Po '([0-9]+)')

        echo "*********************************Start $SERVICE TaskID $TASKID"
        sleep 2
        LOOPESCAPE="false"
        until [ "$LOOPESCAPE" == true ]; do
            TASKSTATUS=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/requests/$TASKID | grep "request_status" | grep -Po '([A-Z]+)')
            if [ "$TASKSTATUS" == COMPLETED ]; then
                LOOPESCAPE="true"
            fi
            echo "*********************************Start $SERVICE Task Status $TASKSTATUS"
            sleep 2
        done
        echo "*********************************$SERVICE Service Started..."
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

enableSparkLLAP () {
	echo "*********************************Installing Spark-LLAP Binaries..."
	wget -P /usr/hdp/current/spark-client/lib/ http://repo.hortonworks.com/content/repositories/releases/com/hortonworks/spark-llap/1.0.0.2.5.3.0-37/spark-llap-1.0.0.2.5.3.0-37-assembly.jar
	echo "*********************************Configuring Spark-LLAP..."
	/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME spark-defaults spark.sql.hive.hiveserver2.url "jdbc:hive2://$HIVESERVER_INTERACTIVE_HOST:10500"
	sleep 1
	/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME spark-defaults spark.jars "/usr/hdp/current/spark-client/lib/spark-llap-1.0.0.2.5.3.0-37-assembly.jar"
	sleep 1
	/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME spark-defaults spark.hadoop.hive.zookeeper.quorum "$ZK_HOST:2181"
	sleep 1
	/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME spark-defaults spark.hadoop.hive.llap.daemon.service.hosts "@llap0"
	sleep 1
	/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME spark-thrift-sparkconf spark.sql.hive.hiveserver2.url "jdbc:hive2://$HIVESERVER_INTERACTIVE_HOST:10500"
	sleep 1
	/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME spark-thrift-sparkconf spark.jars "/usr/hdp/current/spark-client/lib/spark-llap-1.0.0.2.5.3.0-37-assembly.jar"
	sleep 1
	/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME spark-thrift-sparkconf spark.hadoop.hive.zookeeper.quorum "$ZK_HOST:2181"
	sleep 1
	/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME spark-thrift-sparkconf spark.hadoop.hive.llap.daemon.service.hosts "@llap0"
	sleep 1
	/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME spark-env spark_thrift_cmd_opts "--jars /usr/hdp/current/spark-client/lib/spark-llap-1.0.0.2.5.3.0-37-assembly.jar"
}

getHiveServerHost () {
        HIVESERVER_HOST=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/HIVE/components/HIVE_SERVER|grep "host_name"|grep -Po ': "([a-zA-Z0-9\-_!?.]+)'|grep -Po '([a-zA-Z0-9\-_!?.]+)')

        echo $HIVESERVER_HOST
}

getHiveInteractiveServerHost () {
        HIVESERVER_INTERACTIVE_HOST=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/HIVE/components/HIVE_SERVER_INTERACTIVE|grep "host_name"|grep -Po ': "([a-zA-Z0-9\-_!?.]+)'|grep -Po '([a-zA-Z0-9\-_!?.]+)')

        echo $HIVESERVER_INTERACTIVE_HOST
}

getHiveMetaStoreHost () {
        HIVE_METASTORE_HOST=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/HIVE/components/HIVE_METASTORE|grep "host_name"|grep -Po ': "([a-zA-Z0-9\-_!?.]+)'|grep -Po '([a-zA-Z0-9\-_!?.]+)')

        echo $HIVE_METASTORE_HOST
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

captureEnvironment () {
	NAMENODE_HOST=$(getNameNodeHost)
	export NAMENODE_HOST=$NAMENODE_HOST
	HIVESERVER_HOST=$(getHiveServerHost)
	export HIVESERVER_HOST=$HIVESERVER_HOST
	HIVESERVER_INTERACTIVE_HOST=$(getHiveInteractiveServerHost)
	export HIVESERVER_INTERACTIVE_HOST=$HIVESERVER_INTERACTIVE_HOST
	HIVE_METASTORE_HOST=$(getHiveMetaStoreHost)
	export HIVE_METASTORE_HOST=$HIVE_METASTORE_HOST
	HIVE_METASTORE_URI=thrift://$HIVE_METASTORE_HOST:9083
	export HIVE_METASTORE_URI=$HIVE_METASTORE_URI
	ZK_HOST=$AMBARI_HOST
	export ZK_HOST=$ZK_HOST
	KAFKA_BROKER=$(getKafkaBroker)
	export KAFKA_BROKER=$KAFKA_BROKER
	ATLAS_HOST=$(getAtlasHost)
	export ATLAS_HOST=$ATLAS_HOST
	env
	
	echo "export NAMENODE_HOST=$NAMENODE_HOST" >> /etc/bashrc
	echo "export ZK_HOST=$ZK_HOST" >> /etc/bashrc
	echo "export KAFKA_BROKER=$KAFKA_BROKER" >> /etc/bashrc
	echo "export ATLAS_HOST=$ATLAS_HOST" >> /etc/bashrc
	echo "export HIVE_METASTORE_HOST=$HIVE_METASTORE_HOST" >> /etc/bashrc
	echo "export HIVE_METASTORE_URI=$HIVE_METASTORE_URI" >> /etc/bashrc

	echo "export NAMENODE_HOST=$NAMENODE_HOST" >> ~/.bash_profile
	echo "export ZK_HOST=$ZK_HOST" >> ~/.bash_profile
	echo "export KAFKA_BROKER=$KAFKA_BROKER" >> ~/.bash_profile
	echo "export ATLAS_HOST=$ATLAS_HOST" >> ~/.bash_profile
	echo "export HIVE_METASTORE_HOST=$HIVE_METASTORE_HOST" >> ~/.bash_profile
	echo "export HIVE_METASTORE_URI=$HIVE_METASTORE_URI" >> ~/.bash_profile

	. ~/.bash_profile
}

installMySQL (){
	yum remove -y mysql57-community*
	yum remove -y mysql56-server*
	yum remove -y mysql-community*
	rm -Rvf /var/lib/mysql

	yum install -y epel-release
	yum install -y libffi-devel.x86_64
	ln -s /usr/lib64/libffi.so.6 /usr/lib64/libffi.so.5

	yum install -y mysql-connector-java*
	ambari-server setup --jdbc-db=mysql --jdbc-driver=/usr/share/java/mysql-connector-java.jar


	if [ $(cat /etc/system-release|grep -Po Amazon) == Amazon ]; then       	
		yum install -y mysql56-server
		service mysqld start
	else
		yum localinstall -y https://dev.mysql.com/get/mysql-community-release-el7-5.noarch.rpm
		yum install -y mysql-community-server
		#yum localinstall -y https://dev.mysql.com/get/mysql57-community-release-el7-8.noarch.rpm
#yum install -y mysql-community-server
		systemctl start mysqld.service
	fi
}

setupRangerDataStore (){
mysql --execute="CREATE USER 'rangerdba'@'localhost' IDENTIFIED BY 'rangerdba';"
mysql --execute="GRANT ALL PRIVILEGES ON *.* TO 'rangerdba'@'localhost';"
mysql --execute="CREATE USER 'rangerdba'@'%' IDENTIFIED BY 'rangerdba';"
mysql --execute="GRANT ALL PRIVILEGES ON *.* TO 'rangerdba'@'%';"
mysql --execute="GRANT ALL PRIVILEGES ON *.* TO 'rangerdba'@'localhost' WITH GRANT OPTION;"
mysql --execute="GRANT ALL PRIVILEGES ON *.* TO 'rangerdba'@'%' WITH GRANT OPTION;"
mysql --execute="FLUSH PRIVILEGES;"
mysql --execute="COMMIT;"
}

if [ ! -d "/usr/jdk64" ]; then
	echo "*********************************Install and Enable Oracle JDK 8"
	wget http://public-repo-1.hortonworks.com/ARTIFACTS/jdk-8u77-linux-x64.tar.gz
	tar -vxzf jdk-8u77-linux-x64.tar.gz -C /usr
	mv /usr/jdk1.8.0_77 /usr/jdk64
	alternatives --install /usr/bin/java java /usr/jdk64/bin/java 3
	alternatives --install /usr/bin/javac javac /usr/jdk64/bin/javac 3
	alternatives --install /usr/bin/jar jar /usr/jdk64/bin/jar 3
	export JAVA_HOME=/usr/jdk64
	echo "export JAVA_HOME=/usr/jdk64" >> /etc/bashrc
fi

export AMBARI_HOST=$(hostname -f)
echo "*********************************AMABRI HOST IS: $AMBARI_HOST"

export CLUSTER_NAME=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters |grep cluster_name|grep -Po ': "(.+)'|grep -Po '[a-zA-Z0-9\-_!?.]+')

if [[ -z $CLUSTER_NAME ]]; then
        echo "Could not connect to Ambari Server. Please run the install script on the same host where Ambari Server is installed."
        exit 1
else
       	echo "*********************************CLUSTER NAME IS: $CLUSTER_NAME"
fi

export ROOT_PATH=$(pwd)
echo "*********************************ROOT PATH IS: $ROOT_PATH"

export HADOOP_USER_NAME=hdfs
echo "*********************************HADOOP_USER_NAME set to HDFS"

echo "*********************************Waiting for cluster install to complete..."
waitForServiceToStart YARN

waitForServiceToStart HDFS

waitForServiceToStart HIVE

waitForServiceToStart ZOOKEEPER

sleep 10

export VERSION=`hdp-select status hadoop-client | sed 's/hadoop-client - \([0-9]\.[0-9]\).*/\1/'`
export INTVERSION=$(echo $VERSION*10 | bc | grep -Po '([0-9][0-9])')
echo "*********************************HDP VERSION IS: $VERSION"

sleep 2

echo "*********************************Installing Utlities..."
installUtils
sleep 2

echo "*********************************Capturing Environment Data..."
captureEnvironment
sleep 2

echo "*********************************Installing MySQL..."
installMySQL
echo "*********************************Setup Ranger Datastore..."
setupRangerDataStore

echo "*********************************Load Data Plane Client Service into Ambari"
cd $ROOT_PATH
git clone https://github.com/vakshorton/Utils
cp -Rvf $ROOT_PATH/Utils/DATA_PLANE_CLIENT /var/lib/ambari-server/resources/stacks/HDP/$VERSION/services/

sleep 2
echo "*********************************Create admin user folder in HDFS..."
hadoop fs -mkdir /user/admin
hadoop fs -chown admin:hdfs /user/admin

sleep 2
#echo "*********************************Checking Spark Configurations..."
#enableSparkLLAP
#stopService SPARK
#startService SPARK
echo "*********************************Restarting Ambari... "
ambari-server stop
ambari-server restart

echo "*********************************Installation Complete... "
startServiceAndComplete MAPREDUCE2
cd $ROOT_PATH

exit 0