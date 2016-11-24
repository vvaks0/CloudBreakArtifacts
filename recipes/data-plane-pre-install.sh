#!/bin/bash
exec > >(tee -i preProvisioning.log)
exec 2>&1
echo "*********************************Install and Enable Open JDK 8"
yum install -y wget
yum install -y java-1.8.0-openjdk-devel
echo "*********************************Install and Enable Oracle JDK 8"
wget http://public-repo-1.hortonworks.com/ARTIFACTS/jdk-8u77-linux-x64.tar.gz
tar -vxzf jdk-8u77-linux-x64.tar.gz -C /usr
mv /usr/jdk1.8.0_77 /usr/jdk64
alternatives --install /usr/bin/java java /usr/jdk64/bin/java 3
alternatives --install /usr/bin/javac javac /usr/jdk64/bin/javac 3
alternatives --install /usr/bin/jar jar /usr/jdk64/bin/jar 3
export JAVA_HOME=/usr/jdk64
echo "export JAVA_HOME=/usr/jdk64" >> /etc/bashrc

echo "*********************************Configure Postgres for Ranger"
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

exit 0