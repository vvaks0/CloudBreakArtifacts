#!/bin/bash
#Dataplane install

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
		service docker start
		chkconfig --levels 3 dockerd on
	else
		yum install -y docker
		systemctl start dockerd.service
		systemctl enable dockerd.service
	fi
	
	echo " 				  *****************Configuring Docker Permissions..."
	groupadd docker
	gpasswd -a yarn docker
	echo " 				  *****************Registering Docker to Start on Boot..."
	service docker start
	chkconfig --add docker
	chkconfig docker on
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
		chkconfig --levels 3 mysqld on
	else
		yum localinstall -y https://dev.mysql.com/get/mysql-community-release-el7-5.noarch.rpm
		yum install -y mysql-community-server

		systemctl start mysqld.service
		systemctl enable mysqld.service
	fi
}

setupRangerDataStore (){
mysql --execute="CREATE USER 'rangerdba'@'localhost' IDENTIFIED BY 'rangerdba';"
mysql --execute="GRANT ALL PRIVILEGES ON *.* TO 'rangerdba'@'localhost';"
mysql --execute="CREATE USER 'rangerdba'@'%' IDENTIFIED BY 'rangerdba';"
mysql --execute="GRANT ALL PRIVILEGES ON *.* TO 'rangerdba'@'%';"
mysql --execute="GRANT ALL PRIVILEGES ON *.* TO 'rangerdba'@'localhost' WITH GRANT OPTION;"
mysql --execute="GRANT ALL PRIVILEGES ON *.* TO 'rangerdba'@'%' WITH GRANT OPTION;"
mysql --execute="CREATE USER 'beacon'@'%' IDENTIFIED BY 'beacon';"
mysql --execute="GRANT ALL PRIVILEGES ON beacon.* TO 'beacon'@'%' WITH GRANT OPTION;"
mysql --execute="FLUSH PRIVILEGES;"
mysql --execute="CREATE DATABASE beacon;"
mysql --execute="COMMIT;"
}

installUtils
sleep 2
installMySQL
sleep 2
setupRangerDataStore

wget http://private-repo-1.hortonworks.com/DLM/centos7/1.x/updates/1.0.0.0-81/tars/beacon/beacon-ambari-mpack-1.0.0.0-81.tar.gz
sleep 2
ambari-server install-mpack --mpack beacon-ambari-mpack-*.tar.gz --verbose
sleep 2
git clone https://github.com/hortonworks/dataplane_profilers
sleep 2
cd dataplane_profilers/mpack
sleep 2
mvn clean install
sleep 2
ambari-server install-mpack --mpack=target/dpprofiler-ambari-mpack-1.0.0.tar.gz --verbose
sleep 2
ambari-server restart
sleep 2
#Use Ambari to install DSS Profiler and DLM Beacon

#usermod -a -G hdfs beacon
setenforce 0
sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/sysconfig/selinux

wget http://private-repo-1.hortonworks.com/DP/centos7/1.x/updates/1.0.0.0-75/tars/dp_dlm/dp-1.0.0.0-75.tar.gz
wget http://private-repo-1.hortonworks.com/DP/centos7/1.x/updates/1.0.0.0-75/tars/dp_dlm/dlm-1.0.0.0-75.tar.gz

tar -xzf dp-1.0.0.0-75.tar.gz

tar -xzf dlm-1.0.0.0-75.tar.gz

cd /root/dp-core/bin/
./dpdeploy.sh load

./dpdeploy.sh init --all
172.31.65.79

cd /root/dlm/bin
./dlmdeploy.sh load
./dlmdeploy.sh init  
172.31.65.79

172.18.0.3

