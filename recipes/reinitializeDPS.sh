#!/bin/bash
echo "LDAP Server Address:"
read LDAP_HOST

echo "LDAP Bind User:"
LDAP_BIND_USER="uid=admin,ou=people,dc=hadoop,dc=apache,dc=org"
echo $LDAP_BIND_USER
#read LDAP_BIND_USER

echo "LDAP Bind Password:"
read -s LDAP_BIND_PASSWORD
echo "ARE YOU SURE? ALL DPS DATA WILL BE WIPED OUT!!! (YES/NO)"
read CONFIRM
if [ $CONFIRM == "YES" ]
then
        cd /usr/dss-app/current/apps/dss/bin/
        ./dssdeploy.sh destroy
        cd /usr/dlm-app/current/apps/dlm/bin/
        ./dlmdeploy.sh destroy
        cd /usr/dp/current/core/bin/
        ./dpdeploy.sh destroy --all
        ./dpdeploy.sh init --all
        cd /usr/dss-app/current/apps/dss/bin/
        ./dssdeploy.sh init
        cd /usr/dlm-app/current/apps/dlm/bin/
        ./dlmdeploy.sh init
	
	#$DPS_IS_READY="false"
        #until [ $DPS_IS_READY ]; do
        #    echo "Waiting for DPS to initialize..."
	#     	sleep 2
	#     	if [ "$(curl -kI -u admin:admin -X GET https://$(hostname -f)/api/knox/ldap |head -n 1|cut -d$' ' -f2)" == "200" ]; then
        #     	DPS_IS_READY="true"
        #    fi
        #done
		
	#	echo "DPS is ready... Binding to LDAP..."
	#	echo "LDAP Bind Status: "
	#	$(curl -k -u admin:admin -H "Content-Type: application/json" -d "{ \"ldapUrl\": \"ldap://$LDAP_HOST:33389\", \"bindDn\": \"$LDAP_BIND_USER\", \"password\": \"$LDAP_BIND_PASSWORD\", \"userSearchBase\": \"ou=people,dc=hadoop,dc=apache,dc=org\", \"userSearchAttributeName\": \"uid\", \"userObjectClass\": \"person\", \"groupSearchBase\": \"ou=groups,dc=hadoop,dc=apache,dc=org\", \"groupSearchAttributeName\": \"cn\", \"groupObjectClass\": \"groupofnames\", \"groupMemberAttributeName\": \"member\" }" -X POST https://$(hostname -f)/api/knox/configure)
	#	echo ""
fi