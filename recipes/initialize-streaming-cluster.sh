#!/bin/bash

wget http://repos.fedorapeople.org/repos/dchen/apache-maven/epel-apache-maven.repo -O /etc/yum.repos.d/epel-apache-maven.repo
sed -i s/\$releasever/6/g /etc/yum.repos.d/epel-apache-maven.repo
yum install -y apache-maven

wget http://nexus-private.hortonworks.com/nexus/content/groups/public/org/apache/phoenix/phoenix-client/5.0.0.3.0.0.0-1634/phoenix-client-5.0.0.3.0.0.0-1634.jar
mkdir -p /usr/hdf/current/phoenix
chmod -R 755 /usr/hdf
cp phoenix-client-5.0.0.3.0.0.0-1634.jar /usr/hdf/current/phoenix
chmod -R 777 /usr/hdf/current/phoenix

useradd -m nifi

echo -n | openssl s_client -connect api.binance.com:443      | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > binance.cert
echo -n | openssl s_client -connect api.gdax.com:443         | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > gdax.cert
echo -n | openssl s_client -connect api.gemini.com:443       | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > gemini.cert
echo -n | openssl s_client -connect sandbox.gdax.com:443     | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > sandbox.gdax.cert
echo -n | openssl s_client -connect exchange.sandbox.gemini.com:443   | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > sandbox.gemini.cert

keytool -import -v -trustcacerts -file gdax.cert -alias gdax  -keystore /home/nifi/keystore.jks -storepass letmein! -noprompt
keytool -import -v -trustcacerts -file gemini.cert -alias gemini -keystore /home/nifi/keystore.jks -storepass letmein! -noprompt
keytool -import -v -trustcacerts -file binance.cert -alias binance -keystore /home/nifi/keystore.jks -storepass letmein! -noprompt
keytool -import -v -trustcacerts -file sandbox.gdax.cert -alias sandbox.gdax  -keystore /home/nifi/keystore.jks -storepass letmein! -noprompt
keytool -import -v -trustcacerts -file sandbox.gemini.cert -alias sandbox.gemini -keystore /home/nifi/keystore.jks -storepass letmein! -noprompt

chown nifi:nifi -R /home/nifi
