#!/bin/bash	

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
mysql --execute="CREATE USER 'rangerdba'@'localhost' IDENTIFIED BY 'rangerdba'"
mysql --execute="CREATE USER 'rangerdba'@'%' IDENTIFIED BY 'rangerdba'"
mysql --execute="CREATE USER 'druid'@'%' IDENTIFIED BY 'druid'"
mysql --execute="CREATE USER 'registry'@'%' IDENTIFIED BY 'registry'"
mysql --execute="CREATE USER 'streamline'@'%' IDENTIFIED BY 'streamline'"
mysql --execute="GRANT ALL PRIVILEGES ON *.* TO 'rangerdba'@'localhost'"
mysql --execute="GRANT ALL PRIVILEGES ON *.* TO 'rangerdba'@'%'"
mysql --execute="GRANT ALL PRIVILEGES ON *.* TO 'rangerdba'@'localhost' WITH GRANT OPTION"
mysql --execute="GRANT ALL PRIVILEGES ON *.* TO 'rangerdba'@'%' WITH GRANT OPTION"
mysql --execute="GRANT ALL PRIVILEGES ON druid.* TO 'druid'@'%' WITH GRANT OPTION"
mysql --execute="GRANT ALL PRIVILEGES ON registry.* TO 'registry'@'%' WITH GRANT OPTION"
mysql --execute="GRANT ALL PRIVILEGES ON streamline.* TO 'streamline'@'%' WITH GRANT OPTION"
mysql --execute="FLUSH PRIVILEGES"
mysql --execute="COMMIT"