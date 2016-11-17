#!/bin/bash
exec > >(tee -i preProvisioning.log)
exec 2>&1

export AMBARI_HOST=$(hostname -f)
echo "*********************************AMABRI HOST IS: $AMBARI_HOST"

export CLUSTER_NAME=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters |grep cluster_name|grep -Po ': "(.+)'|grep -Po '[a-zA-Z0-9\-_!?.]+')

if [[ -z $CLUSTER_NAME ]]; then
        echo "Could not connect to Ambari Server. Please run the install script on the same host where Ambari Server is installed."
        exit 1
else
       	echo "*********************************CLUSTER NAME IS: $CLUSTER_NAME"
fi

git clone https://github.com/vakshorton/CloudBreakArtifacts
cd CloudBreakArtifacts
export ROOT_PATH=$(pwd)
echo "*********************************ROOT PATH IS: $ROOT_PATH"

createTransactionHistoryTable () {	
	HQL="CREATE TABLE IF NOT EXISTS TransactionHistory ( accountNumber String,
                                                    fraudulent String,
                                                    merchantId String,
                                                    merchantType String,
                                                    amount Int,
                                                    currency String,
                                                    isCardPresent String,
                                                    latitude Double,
                                                    longitude Double,
                                                    transactionId String,
                                                    transactionTimeStamp String,
                                                    distanceFromHome Double,                                                                          
                                                    distanceFromPrev Double)
	COMMENT 'Customer Credit Card Transaction History'
	PARTITIONED BY (accountType String)
	CLUSTERED BY (merchantType) INTO 30 BUCKETS
	STORED AS ORC;"
	
	# CREATE Customer Transaction History Table
	beeline -u jdbc:hive2://$HIVESERVER_HOST:10000/default -d org.apache.hive.jdbc.HiveDriver -e "$HQL"
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

getKafkaBroker () {
       	KAFKA_BROKER=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/KAFKA/components/KAFKA_BROKER |grep "host_name"|grep -Po ': "([a-zA-Z0-9\-_!?.]+)'|grep -Po '([a-zA-Z0-9\-_!?.]+)')
       	
       	echo $KAFKA_BROKER
}

getAtlasHost () {
       	ATLAS_HOST=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/ATLAS/components/ATLAS_SERVER |grep "host_name"|grep -Po ': "([a-zA-Z0-9\-_!?.]+)'|grep -Po '([a-zA-Z0-9\-_!?.]+)')
       	
       	echo $ATLAS_HOST
}

export JAVA_HOME=/usr/jdk64
NAMENODE_HOST=$(getNameNodeHost)
export NAMENODE_HOST=$NAMENODE_HOST
HIVESERVER_HOST=$(getHiveServerHost)
export HIVESERVER_HOST=$HIVESERVER_HOST
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

#createTransactionHistoryTable

#Configure Postgres for Ranger
yum install -y postgresql-jdbc*
echo "host all all 127.0.0.1/32 md5" >> /var/lib/pgsql/data/pg_hba.conf
echo "CREATE DATABASE rangerdb;" | sudo -u postgres psql -U postgres
echo "CREATE USER rangerdba WITH PASSWORD 'ranger';" | sudo -u postgres psql -U postgres
echo "GRANT ALL PRIVILEGES ON DATABASE rangerdb TO rangerdba;" | sudo -u postgres psql -U postgres

ambari-server setup --jdbc-db=postgres --jdbc-driver=/usr/share/java/postgresql-jdbc.jar

export HADOOP_CLASSPATH=${HADOOP_CLASSPATH}:${JAVA_JDBC_LIBS}:/usr/share/java/postgresql-jdbc.jar

echo "local all rangerdba,rangerlogger trust" >> /var/lib/pgsql/data/pg_hba.conf
echo "host  all rangerdba,rangerlogger 0.0.0.0/0 trust" >> /var/lib/pgsql/data/pg_hba.conf
echo "host  all rangerdba,rangerlogger ::/0 trust" >> /var/lib/pgsql/data/pg_hba.conf

sudo -u postgres /usr/bin/pg_ctl -D /var/lib/pgsql/data reload

	echo "*********************************Creating RANGER service..."
       	# Create RANGER service
       	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/RANGER

       	sleep 2
       	# Add RANGER_ADMIN component to service
       	echo "*********************************Adding RANGER_ADMIN component..."       	
       	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/RANGER/components/RANGER_ADMIN
       	
       	sleep 2
       	# Add RANGER_TAGSYNC component to service
       	echo "*********************************Adding RANGER_TAGSYNC component..."
       	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/RANGER/components/RANGER_TAGSYNC
       	
       	sleep 2
       	# Add RANGER_USERSYNC component to service
       	echo "*********************************Adding RANGER_USERSYNC component..."
       	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/RANGER/components/RANGER_USERSYNC

       	sleep 2
       	echo "*********************************Creating RANGER configuration..."

       	# Apply environment variables to RANGER configuration
sed -r -i "s;\{\{ZK_HOST\}\};$ZK_HOST;" $ROOT_PATH/ranger-config/ranger-admin-site
sed -r -i "s;\{\{AMBARI_HOST\}\};$AMBARI_HOST;" $ROOT_PATH/ranger-config/ranger-admin-site
sed -r -i "s;\{\{AMBARI_HOST\}\};$AMBARI_HOST;" $ROOT_PATH/ranger-config/ranger-env
sed -r -i "s;\{\{NAMENODE_HOST\}\};$NAMENODE_HOST;" $ROOT_PATH/ranger-config/ranger-env
sed -r -i "s;\{\{ATLAS_HOST\}\};$ATLAS_HOST;" $ROOT_PATH/ranger-config/ranger-tagsync-site
		
		# Create and apply configuration
		/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME admin-log4j $ROOT_PATH/ranger-config/admin-log4j
		sleep 2
		/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME ranger-admin-site $ROOT_PATH/ranger-config/ranger-admin-site
		sleep 2
		/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME ranger-env $ROOT_PATH/ranger-config/ranger-env
		sleep 2
       	/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME ranger-tagsync-site $ROOT_PATH/ranger-config/ranger-tagsync-site
       	sleep 2
       	/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME ranger-ugsync-site $ROOT_PATH/ranger-config/ranger-ugsync-site
       	sleep 2
       	/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME tagsync-log4j $ROOT_PATH/ranger-config/tagsync-log4j
       	sleep 2
		/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME usersync-log4j $ROOT_PATH/ranger-config/usersync-log4j

		echo "*********************************Adding RANGER_ADMIN role to Host..."
       	# Add RANGER_ADMIN role to Ambari host
       	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/hosts/$AMBARI_HOST/host_components/RANGER_ADMIN

		echo "*********************************Adding RANGER_TAGSYNC role to Host..."
       	# Add RANGER_TAGSYNC role to Ambari host
       	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/hosts/$AMBARI_HOST/host_components/RANGER_TAGSYNC

		echo "*********************************Adding RANGER_USERSYNC role to Host..."
       	# Add RANGER_ADMIN role to Ambari host
       	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/hosts/$AMBARI_HOST/host_components/RANGER_USERSYNC
		
       	sleep 30
       	echo "*********************************Installing RANGER Service"
       	# Install RANGER Service
       	TASKID=$(curl -u admin:admin -H "X-Requested-By:ambari" -i -X PUT -d '{"RequestInfo": {"context" :"Install Ranger"}, "Body": {"ServiceInfo": {"maintenance_state" : "OFF", "state": "INSTALLED"}}}' http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/RANGER | grep "id" | grep -Po '([0-9]+)')
		
		sleep 2       	
       	if [ -z $TASKID ]; then
       		until ! [ -z $TASKID ]; do
       			TASKID=$(curl -u admin:admin -H "X-Requested-By:ambari" -i -X PUT -d '{"RequestInfo": {"context" :"Install Ranger"}, "Body": {"ServiceInfo": {"maintenance_state" : "OFF", "state": "INSTALLED"}}}' http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/RANGER | grep "id" | grep -Po '([0-9]+)')
       		 	echo "*********************************AMBARI TaskID " $TASKID
       		done
       	fi
       	
       	echo "*********************************AMBARI TaskID " $TASKID
       	sleep 2
       	LOOPESCAPE="false"
       	until [ "$LOOPESCAPE" == true ]; do
               	TASKSTATUS=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/requests/$TASKID | grep "request_status" | grep -Po '([A-Z]+)')
               	if [ "$TASKSTATUS" == COMPLETED ]; then
                       	LOOPESCAPE="true"
               	fi
               	echo "*********************************Task Status" $TASKSTATUS
               	sleep 2
       	done