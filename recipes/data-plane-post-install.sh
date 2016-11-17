#!/bin/bash

export AMBARI_HOST=$(hostname -f)
echo "*********************************AMABRI HOST IS: $AMBARI_HOST"

export CLUSTER_NAME=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters |grep cluster_name|grep -Po ': "(.+)'|grep -Po '[a-zA-Z0-9\-_!?.]+')

if [[ -z $CLUSTER_NAME ]]; then
        echo "Could not connect to Ambari Server. Please run the install script on the same host where Ambari Server is installed."
        exit 1
else
       	echo "*********************************CLUSTER NAME IS: $CLUSTER_NAME"
fi

getHiveServerHost () {
        HIVESERVER_HOST=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/HIVE/components/HIVE_SERVER|grep "host_name"|grep -Po ': "([a-zA-Z0-9\-_!?.]+)'|grep -Po '([a-zA-Z0-9\-_!?.]+)')

        echo $HIVESERVER_HOST
}

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

HIVESERVER_HOST=$(getHiveServerHost)
export HIVESERVER_HOST=$HIVESERVER_HOST

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

sed -r -i "s;\{\{ZK_HOST\}\};$ZK_HOST;" ranger-config/ranger-admin-site
sed -r -i "s;\{\{AMBARI_HOST\}\};$AMBARI_HOST;" ranger-config/ranger-admin-site
sed -r -i "s;\{\{AMBARI_HOST\}\};$AMBARI_HOST;" ranger-config/ranger-env
sed -r -i "s;\{\{NAMENODE_HOST\}\};$NAMENODE_HOST;" ranger-config/ranger-env
sed -r -i "s;\{\{ATLAS_HOST\}\};$ATLAS_HOST;" ranger-config/ranger-tagsync-site
