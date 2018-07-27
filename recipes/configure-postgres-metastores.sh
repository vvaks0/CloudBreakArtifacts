#!/bin/bash

export DPS_HOST=$1

#disable ambari ldap pagination to avoid NPE on sync
echo "authentication.ldap.pagination.enabled=false" >> /etc/ambari-server/conf/ambari.properties

#configure metastore users and permissions on local ambari database
echo "CREATE DATABASE ranger;" | sudo -u postgres psql -U postgres
echo "CREATE USER rangerdba WITH PASSWORD 'rangerdba';" | sudo -u postgres psql -U postgres
echo "CREATE USER rangeradmin WITH PASSWORD 'ranger'" | sudo -u postgres psql -U postgres
echo "GRANT ALL PRIVILEGES ON DATABASE ranger TO rangerdba;" | sudo -u postgres psql -U postgres
echo "GRANT ALL PRIVILEGES ON DATABASE ranger TO rangeradmin;" | sudo -u postgres psql -U postgres

ambari-server setup --jdbc-db=postgres --jdbc-driver=/usr/share/java/postgresql-jdbc.jar

export HADOOP_CLASSPATH=${HADOOP_CLASSPATH}:${JAVA_JDBC_LIBS}:/connector jar path

if [[ $(cat /etc/system-release|grep -Po Amazon) == "Amazon" ]]; then       		
	echo '' >  /var/lib/pgsql/9.5/data/pg_hba.conf
	echo 'host  ambari ambari 									    0.0.0.0/0 		md5			' >> /var/lib/pgsql/9.5/data/pg_hba.conf
	echo 'local ambari ambari 									              		md5			' >> /var/lib/pgsql/9.5/data/pg_hba.conf
	echo 'local all postgres,hive,rangerdba,rangeradmin,rangerlogger,druid           trust		' >> /var/lib/pgsql/9.5/data/pg_hba.conf
	echo 'host  all postgres,hive,rangerdba,rangeradmin,rangerlogger,druid 0.0.0.0/0 trust		' >> /var/lib/pgsql/9.5/data/pg_hba.conf
	echo 'host  all postgres,hive,rangerdba,rangeradmin,rangerlogger,druid ::/0      trust		' >> /var/lib/pgsql/9.5/data/pg_hba.conf
	echo 'local all             all                                     				peer			' >> /var/lib/pgsql/9.5/data/pg_hba.conf
	echo 'host  all             all             127.0.0.1/32            		 		ident		' >> /var/lib/pgsql/9.5/data/pg_hba.conf
	echo 'host  all             all             ::1/128                 		 		ident		' >> /var/lib/pgsql/9.5/data/pg_hba.conf
	
	sudo -u postgres /usr/pgsql-9.5/bin/pg_ctl -D /var/lib/pgsql/9.5/data/ reload
else
	echo '' >  /var/lib/pgsql/data/pg_hba.conf
	echo 'host  ambari ambari 									    0.0.0.0/0 		md5			' >> /var/lib/pgsql/data/pg_hba.conf
	echo 'local ambari ambari 									              		md5			' >> /var/lib/pgsql/data/pg_hba.conf
	echo 'local all postgres,hive,rangerdba,rangeradmin,rangerlogger,druid           trust		' >> /var/lib/pgsql/data/pg_hba.conf
	echo 'host  all postgres,hive,rangerdba,rangeradmin,rangerlogger,druid 0.0.0.0/0 trust		' >> /var/lib/pgsql/data/pg_hba.conf
	echo 'host  all postgres,hive,rangerdba,rangeradmin,rangerlogger,druid ::/0      trust		' >> /var/lib/pgsql/data/pg_hba.conf
	echo 'local all             all                                     		 		peer			' >> /var/lib/pgsql/data/pg_hba.conf
	echo 'host  all             all             127.0.0.1/32            		 		ident		' >> /var/lib/pgsql/data/pg_hba.conf
	echo 'host  all             all             ::1/128                 		 		ident		' >> /var/lib/pgsql/data/pg_hba.conf
	
	sudo -u postgres pg_ctl -D /var/lib/pgsql/data/ reload
fi

#create sso token topology to enable synch with dps

echo "
<topology>
   <uri>https://$(hostname -f):8443/gateway/token</uri>
   <name>token</name>
   <gateway>
      <provider>
         <role>federation</role>
         <name>SSOCookieProvider</name>
         <enabled>true</enabled>
         <param>
            <name>sso.authentication.provider.url</name>
            <value>https://$(hostname -f):8443/gateway/knoxsso/api/v1/websso</value>
         </param>
         <param>
            <name>sso.token.verification.pem</name>
            <value>
$(echo "" | openssl s_client -showcerts -connect $DPS_HOST:443 | openssl x509 -outform pem)
			</value>
         </param>
      </provider>
      <provider>
         <role>identity-assertion</role>
         <name>HadoopGroupProvider</name>
         <enabled>true</enabled>
      </provider>
      <provider>
         <role>authorization</role>
         <name>XASecurePDPKnox</name>
         <enabled>true</enabled>
      </provider>
   </gateway>

   <service>
      <role>KNOXTOKEN</role>
      <param>
         <name>knox.token.ttl</name>
         <value>500000</value>
      </param>
      <param>
         <name>knox.token.client.data</name>
         <value>cookie.name=hadoop-jwt</value>
      </param>
      <param>
         <name>main.ldapRealm.authorizationEnabled</name>
         <value>true</value>
      </param>
   </service>
</topology>" | sed 's/-----BEGIN CERTIFICATE-----//' | sed 's/-----END CERTIFICATE-----//' | tee /etc/knox/conf/topologies/token.xml
exit 0
