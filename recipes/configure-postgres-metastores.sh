#!/bin/bash

#disable ambari ldap pagination to avoid NPE on sync
echo "authentication.ldap.pagination.enabled=false" >> /etc/ambari-server/conf/ambari.properties

echo "CREATE DATABASE ranger;" | sudo -u postgres psql -U postgres
echo "CREATE USER rangerdba WITH PASSWORD 'rangerdba';" | sudo -u postgres psql -U postgres
echo "CREATE USER rangeradmin WITH PASSWORD 'ranger'" | sudo -u postgres psql -U postgres
echo "GRANT ALL PRIVILEGES ON DATABASE ranger TO rangerdba;" | sudo -u postgres psql -U postgres
echo "GRANT ALL PRIVILEGES ON DATABASE ranger TO rangeradmin;" | sudo -u postgres psql -U postgres


ambari-server setup --jdbc-db=postgres --jdbc-driver=/usr/share/java/postgresql-jdbc.jar

export HADOOP_CLASSPATH=${HADOOP_CLASSPATH}:${JAVA_JDBC_LIBS}:/connector jar path

if [[ $(cat /etc/system-release|grep -Po Amazon) == "Amazon" ]]; then       		
	echo 'local all postgres,hive,rangerdba,rangeradmin,rangerlogger           trust' >> /var/lib/pgsql/9.5/data/pg_hba.conf
	echo 'host  all postgres,hive,rangerdba,rangeradmin,rangerlogger 0.0.0.0/0 trust' >> /var/lib/pgsql/9.5/data/pg_hba.conf
	echo 'host  all postgres,hive,rangerdba,rangeradmin,rangerlogger ::/0      trust' >> /var/lib/pgsql/9.5/data/pg_hba.conf
	echo 'host  all postgres,hive,rangerdba,rangeradmin,rangerlogger ::/0      trust' >> /var/lib/pgsql/9.5/data/pg_hba.conf
	
	sudo -u postgres /usr/pgsql-9.5/bin/pg_ctl -D /var/lib/pgsql/9.5/data/ reload
else
	echo 'local all postgres,hive,rangerdba,rangeradmin,rangerlogger           trust' >> /var/lib/pgsql/data/pg_hba.conf
	echo 'host  all postgres,hive,rangerdba,rangeradmin,rangerlogger 0.0.0.0/0 trust' >> /var/lib/pgsql/data/pg_hba.conf
	echo 'host  all postgres,hive,rangerdba,rangeradmin,rangerlogger ::/0      trust' >> /var/lib/pgsql/data/pg_hba.conf
	echo 'host  all postgres,hive,rangerdba,rangeradmin,rangerlogger ::/0      trust' >> /var/lib/pgsql/data/pg_hba.conf
	
	sudo -u postgres pg_ctl -D /var/lib/pgsql/data/ reload
fi