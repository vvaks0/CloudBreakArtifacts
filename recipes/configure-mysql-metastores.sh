#!/bin/bash	

export DPS_HOST=$1

#disable ambari ldap pagination to avoid NPE on sync
echo "authentication.ldap.pagination.enabled=false" >> /etc/ambari-server/conf/ambari.properties
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
		systemctl start mysqld.service
	fi
	chkconfig --add mysqld
	chkconfig mysqld on

    ln -s /usr/share/java/mysql-connector-java.jar /usr/hdp/current/hive-client/lib/mysql-connector-java.jar	
	ln -s /usr/share/java/mysql-connector-java.jar /usr/hdp/current/hive-server2-hive2/lib/mysql-connector-java.jar

mysql --execute="CREATE DATABASE druid DEFAULT CHARACTER SET utf8"
mysql --execute="CREATE DATABASE registry DEFAULT CHARACTER SET utf8"
mysql --execute="CREATE DATABASE streamline DEFAULT CHARACTER SET utf8"
mysql --execute="CREATE USER 'ranger'@'localhost' IDENTIFIED BY 'ranger'"
mysql --execute="CREATE USER 'ranger'@'%' IDENTIFIED BY 'ranger'"
mysql --execute="CREATE USER 'rangerdba'@'localhost' IDENTIFIED BY 'rangerdba'"
mysql --execute="CREATE USER 'rangerdba'@'%' IDENTIFIED BY 'rangerdba'"
mysql --execute="CREATE USER 'druid'@'%' IDENTIFIED BY 'druid'"
mysql --execute="CREATE USER 'registry'@'%' IDENTIFIED BY 'registry'"
mysql --execute="CREATE USER 'streamline'@'%' IDENTIFIED BY 'streamline'"
mysql --execute="GRANT ALL PRIVILEGES ON *.* TO 'ranger'@'localhost'"
mysql --execute="GRANT ALL PRIVILEGES ON *.* TO 'ranger'@'%'"
mysql --execute="GRANT ALL PRIVILEGES ON *.* TO 'ranger'@'localhost' WITH GRANT OPTION"
mysql --execute="GRANT ALL PRIVILEGES ON *.* TO 'ranger'@'%' WITH GRANT OPTION"
mysql --execute="GRANT ALL PRIVILEGES ON *.* TO 'rangerdba'@'localhost'"
mysql --execute="GRANT ALL PRIVILEGES ON *.* TO 'rangerdba'@'%'"
mysql --execute="GRANT ALL PRIVILEGES ON *.* TO 'rangerdba'@'localhost' WITH GRANT OPTION"
mysql --execute="GRANT ALL PRIVILEGES ON *.* TO 'rangerdba'@'%' WITH GRANT OPTION"
mysql --execute="GRANT ALL PRIVILEGES ON druid.* TO 'druid'@'%' WITH GRANT OPTION"
mysql --execute="GRANT ALL PRIVILEGES ON registry.* TO 'registry'@'%' WITH GRANT OPTION"
mysql --execute="GRANT ALL PRIVILEGES ON streamline.* TO 'streamline'@'%' WITH GRANT OPTION"
mysql --execute="FLUSH PRIVILEGES"
mysql --execute="COMMIT"

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