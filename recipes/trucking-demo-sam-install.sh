#!/bin/bash

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
	else
		echo " 				  *****************Adding Docker Yum Repo..."
		tee /etc/yum.repos.d/docker.repo <<-'EOF'
		[dockerrepo]
		name=Docker Repository
		baseurl=https://yum.dockerproject.org/repo/main/centos/$releasever/
		enabled=1
		gpgcheck=1
		gpgkey=https://yum.dockerproject.org/gpg
		EOF
		rpm -iUvh http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
		yum install -y docker-io
	fi
	
	echo " 				  *****************Configuring Docker Permissions..."
	groupadd docker
	gpasswd -a yarn docker
	echo " 				  *****************Registering Docker to Start on Boot..."
	service docker start
	chkconfig --add docker
	chkconfig docker on
}

waitForAmbari () {
       	# Wait for Ambari
       	LOOPESCAPE="false"
       	until [ "$LOOPESCAPE" == true ]; do
        TASKSTATUS=$(curl -u admin:admin -I -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME | grep -Po 'OK')
        if [ "$TASKSTATUS" == OK ]; then
                LOOPESCAPE="true"
                TASKSTATUS="READY"
        else
               	AUTHSTATUS=$(curl -u admin:admin -I -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME | grep HTTP | grep -Po '( [0-9]+)'| grep -Po '([0-9]+)')
               	if [ "$AUTHSTATUS" == 403 ]; then
               	echo "THE AMBARI PASSWORD IS NOT SET TO: admin"
               	echo "RUN COMMAND: ambari-admin-password-reset, SET PASSWORD: admin"
               	exit 403
               	else
                TASKSTATUS="PENDING"
               	fi
       	fi
       	echo "Waiting for Ambari..."
        echo "Ambari Status... " $TASKSTATUS
        sleep 2
       	done
}

serviceExists () {
       	SERVICE=$1
       	SERVICE_STATUS=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/$SERVICE | grep '"status" : ' | grep -Po '([0-9]+)')

       	if [ "$SERVICE_STATUS" == 404 ]; then
       		echo 0
       	else
       		echo 1
       	fi
}

getServiceStatus () {
       	SERVICE=$1
       	SERVICE_STATUS=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/$SERVICE | grep '"state" :' | grep -Po '([A-Z]+)')

       	echo $SERVICE_STATUS
}

waitForService () {
       	# Ensure that Service is not in a transitional state
       	SERVICE=$1
       	SERVICE_STATUS=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/$SERVICE | grep '"state" :' | grep -Po '([A-Z]+)')
       	sleep 2
       	echo "$SERVICE STATUS: $SERVICE_STATUS"
       	LOOPESCAPE="false"
       	if ! [[ "$SERVICE_STATUS" == STARTED || "$SERVICE_STATUS" == INSTALLED ]]; then
        until [ "$LOOPESCAPE" == true ]; do
                SERVICE_STATUS=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/$SERVICE | grep '"state" :' | grep -Po '([A-Z]+)')
            if [[ "$SERVICE_STATUS" == STARTED || "$SERVICE_STATUS" == INSTALLED ]]; then
                LOOPESCAPE="true"
            fi
            echo "*********************************$SERVICE Status: $SERVICE_STATUS"
            sleep 2
        done
       	fi
}

waitForServiceToStart () {
       	# Ensure that Service is not in a transitional state
       	SERVICE=$1
       	SERVICE_STATUS=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/$SERVICE | grep '"state" :' | grep -Po '([A-Z]+)')
       	sleep 2
       	echo "$SERVICE STATUS: $SERVICE_STATUS"
       	LOOPESCAPE="false"
       	if ! [[ "$SERVICE_STATUS" == STARTED ]]; then
        	until [ "$LOOPESCAPE" == true ]; do
                SERVICE_STATUS=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/$SERVICE | grep '"state" :' | grep -Po '([A-Z]+)')
            if [[ "$SERVICE_STATUS" == STARTED ]]; then
                LOOPESCAPE="true"
            fi
            echo "*********************************$SERVICE Status: $SERVICE_STATUS"
            sleep 2
        done
       	fi
}

stopService () {
       	SERVICE=$1
       	SERVICE_STATUS=$(getServiceStatus $SERVICE)
       	echo "*********************************Stopping Service $SERVICE ..."
       	if [ "$SERVICE_STATUS" == STARTED ]; then
        TASKID=$(curl -u admin:admin -H "X-Requested-By:ambari" -i -X PUT -d "{\"RequestInfo\": {\"context\": \"Stop $SERVICE\"}, \"ServiceInfo\": {\"maintenance_state\" : \"OFF\", \"state\": \"INSTALLED\"}}" http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/$SERVICE | grep "id" | grep -Po '([0-9]+)')

        echo "*********************************Stop $SERVICE TaskID $TASKID"
        sleep 2
        LOOPESCAPE="false"
        until [ "$LOOPESCAPE" == true ]; do
            TASKSTATUS=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/requests/$TASKID | grep "request_status" | grep -Po '([A-Z]+)')
            if [ "$TASKSTATUS" == COMPLETED ]; then
                LOOPESCAPE="true"
            fi
            echo "*********************************Stop $SERVICE Task Status $TASKSTATUS"
            sleep 2
        done
        echo "*********************************$SERVICE Service Stopped..."
       	elif [ "$SERVICE_STATUS" == INSTALLED ]; then
       	echo "*********************************$SERVICE Service Stopped..."
       	fi
}

startService (){
       	SERVICE=$1
       	SERVICE_STATUS=$(getServiceStatus $SERVICE)
       	echo "*********************************Starting Service $SERVICE ..."
       	if [ "$SERVICE_STATUS" == INSTALLED ]; then
        TASKID=$(curl -u admin:admin -H "X-Requested-By:ambari" -i -X PUT -d "{\"RequestInfo\": {\"context\": \"Start $SERVICE\"}, \"ServiceInfo\": {\"maintenance_state\" : \"OFF\", \"state\": \"STARTED\"}}" http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/$SERVICE | grep "id" | grep -Po '([0-9]+)')

        echo "*********************************Start $SERVICE TaskID $TASKID"
        sleep 2
        LOOPESCAPE="false"
        until [ "$LOOPESCAPE" == true ]; do
            TASKSTATUS=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/requests/$TASKID | grep "request_status" | grep -Po '([A-Z]+)')
            if [[ "$TASKSTATUS" == COMPLETED || "$TASKSTATUS" == FAILED ]]; then
                LOOPESCAPE="true"
            fi
            echo "*********************************Start $SERVICE Task Status $TASKSTATUS"
            sleep 2
        done
       	elif [ "$SERVICE_STATUS" == STARTED ]; then
       	echo "*********************************$SERVICE Service Started..."
       	fi
}

getComponentStatus () {
       	SERVICE=$1
       	COMPONENT=$2
       	COMPONENT_STATUS=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/$SERVICE/components/$COMPONENT | grep '"state" :' | grep -Po '([A-Z]+)')

       	echo $COMPONENT_STATUS
}

getHiveServerHost () {
        HIVESERVER_HOST=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/HIVE/components/HIVE_SERVER|grep "host_name"|grep -Po ': "([a-zA-Z0-9\-_!?.]+)'|grep -Po '([a-zA-Z0-9\-_!?.]+)')

        echo $HIVESERVER_HOST
}

getHiveMetaStoreHost () {
        HIVE_METASTORE_HOST=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/HIVE/components/HIVE_METASTORE|grep "host_name"|grep -Po ': "([a-zA-Z0-9\-_!?.]+)'|grep -Po '([a-zA-Z0-9\-_!?.]+)')

        echo $HIVE_METASTORE_HOST
}

getStormUIHost () {
        STORMUI_HOST=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/STORM/components/STORM_UI_SERVER|grep "host_name"|grep -Po ': "([a-zA-Z0-9\-_!?.]+)'|grep -Po '([a-zA-Z0-9\-_!?.]+)')

        echo $STORMUI_HOST
}

getRegistryHost () {
       	REGISTRY_HOST=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/REGISTRY/components/REGISTRY_SERVER |grep "host_name"|grep -Po ': "([a-zA-Z0-9\-_!?.]+)'|grep -Po '([a-zA-Z0-9\-_!?.]+)')
       	
       	echo $REGISTRY_HOST
}

getLivyHost () {
       	LIVY_HOST=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/SPARK2/components/LIVY2_SERVER |grep "host_name"|grep -Po ': "([a-zA-Z0-9\-_!?.]+)'|grep -Po '([a-zA-Z0-9\-_!?.]+)')
       	
       	echo $LIVY_HOST
}

getHiveInteractiveServerHost () {
        HIVESERVER_INTERACTIVE_HOST=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/HIVE/components/HIVE_SERVER_INTERACTIVE|grep "host_name"|grep -Po ': "([a-zA-Z0-9\-_!?.]+)'|grep -Po '([a-zA-Z0-9\-_!?.]+)')

        echo $HIVESERVER_INTERACTIVE_HOST
}

getDruidBroker () {
        DRUID_BROKER=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/DRUID/components/DRUID_BROKER|grep "host_name"|grep -Po ': "([a-zA-Z0-9\-_!?.]+)'|grep -Po '([a-zA-Z0-9\-_!?.]+)')

        echo $DRUID_BROKER
}

getKafkaBroker () {
       	KAFKA_BROKER=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/KAFKA/components/KAFKA_BROKER |grep "host_name"|grep -Po ': "([a-zA-Z0-9\-_!?.]+)'|grep -Po '([a-zA-Z0-9\-_!?.]+)')
       	
       	echo $KAFKA_BROKER
}

getAtlasHost () {
       	ATLAS_HOST=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/ATLAS/components/ATLAS_SERVER |grep "host_name"|grep -Po ': "([a-zA-Z0-9\-_!?.]+)'|grep -Po '([a-zA-Z0-9\-_!?.]+)')
       	
       	echo $ATLAS_HOST
}

getNifiHost () {
       	NIFI_HOST=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/NIFI/components/NIFI_MASTER|grep "host_name"|grep -Po ': "([a-zA-Z0-9\-_!?.]+)'|grep -Po '([a-zA-Z0-9\-_!?.]+)')

       	echo $NIFI_HOST
}

captureEnvironment () {
	export NIFI_HOST=$(getNifiHost)
	export NAMENODE_HOST=$(getNameNodeHost)
	export HIVESERVER_HOST=$(getHiveServerHost)
	export HIVE_METASTORE_HOST=$(getHiveMetaStoreHost)
	export HIVE_METASTORE_URI=thrift://$HIVE_METASTORE_HOST:9083
	export ZK_HOST=$AMBARI_HOST
	export KAFKA_BROKER=$(getKafkaBroker)
	export ATLAS_HOST=$(getAtlasHost)
	export COMETD_HOST=$AMBARI_HOST
	env
	echo "export NIFI_HOST=$NIFI_HOST" >> /etc/bashrc
	echo "export NAMENODE_HOST=$NAMENODE_HOST" >> /etc/bashrc
	echo "export ZK_HOST=$ZK_HOST" >> /etc/bashrc
	echo "export KAFKA_BROKER=$KAFKA_BROKER" >> /etc/bashrc
	echo "export ATLAS_HOST=$ATLAS_HOST" >> /etc/bashrc
	echo "export HIVE_METASTORE_HOST=$HIVE_METASTORE_HOST" >> /etc/bashrc
	echo "export HIVE_METASTORE_URI=$HIVE_METASTORE_URI" >> /etc/bashrc
	echo "export COMETD_HOST=$COMETD_HOST" >> /etc/bashrc

	echo "export NIFI_HOST=$NIFI_HOST" >> ~/.bash_profile
	echo "export NAMENODE_HOST=$NAMENODE_HOST" >> ~/.bash_profile
	echo "export ZK_HOST=$ZK_HOST" >> ~/.bash_profile
	echo "export KAFKA_BROKER=$KAFKA_BROKER" >> ~/.bash_profile
	echo "export ATLAS_HOST=$ATLAS_HOST" >> ~/.bash_profile
	echo "export HIVE_METASTORE_HOST=$HIVE_METASTORE_HOST" >> ~/.bash_profile
	echo "export HIVE_METASTORE_URI=$HIVE_METASTORE_URI" >> ~/.bash_profile
	echo "export COMETD_HOST=$COMETD_HOST" >> ~/.bash_profile

	. ~/.bash_profile
}

installDemoControl () {
		echo "*********************************Creating Demo Control service..."
       	# Create Demo Control service
       	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/TRUCKING_DEMO_CONTROL

       	sleep 2
       	echo "*********************************Adding Demo Control component..."
       	# Add Demo Control component to service
       	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/TRUCKING_DEMO_CONTROL/components/TRUCKING_DEMO_CONTROL

       	sleep 2
       	echo "*********************************Creating Demo Control configuration..."
		
		tee control-config <<-'EOF'
			"properties" : {
"democontrol.download_url" : "https://s3.amazonaws.com/vvaks/Data-Loader.zip",
"democontrol.install_dir" : "/root"
			}
		EOF
		
		/var/lib/ambari-server/resources/scripts/configs.sh set $AMBARI_HOST $CLUSTER_NAME control-config control-config
		
       	# Create and apply configuration

       	sleep 2
       	echo "*********************************Adding Creating role to Host..."
       	# Add NIFI Master role to Sandbox host
       	curl -u admin:admin -H "X-Requested-By:ambari" -i -X POST http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/hosts/$AMBARI_HOST/host_components/TRUCKING_DEMO_CONTROL

       	sleep 15
       	echo "*********************************Installing Demo Control Service"
       	# Install Demo Control Service
       	TASKID=$(curl -u admin:admin -H "X-Requested-By:ambari" -i -X PUT -d '{"RequestInfo": {"context" :"Install Demo Control"}, "Body": {"ServiceInfo": {"maintenance_state" : "OFF", "state": "INSTALLED"}}}' http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/TRUCKING_DEMO_CONTROL | grep "id" | grep -Po '([0-9]+)')
       	
       	if [ -z $TASKID ]; then
       		until ! [ -z $TASKID ]; do
       			TASKID=$(curl -u admin:admin -H "X-Requested-By:ambari" -i -X PUT -d '{"RequestInfo": {"context" :"Install Demo Control"}, "Body": {"ServiceInfo": {"maintenance_state" : "OFF", "state": "INSTALLED"}}}' http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTER_NAME/services/TRUCKING_DEMO_CONTROL grep "id" | grep -Po '([0-9]+)')
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
}

deployTemplateToNifi () {
       	TEMPLATE_DIR=$1
       	TEMPLATE_NAME=$2
       	
       	echo "*********************************Importing NIFI Template..."
       	# Import NIFI Template HDF 3.x
       	# TEMPLATE_DIR should have been passed in by the caller install process
       	sleep 1
       	TEMPLATEID=$(curl -v -F template=@"$TEMPLATE_DIR" -X POST http://$NIFI_HOST:9090/nifi-api/process-groups/root/templates/upload | grep -Po '<id>([a-z0-9-]+)' | grep -Po '>([a-z0-9-]+)' | grep -Po '([a-z0-9-]+)')
       	sleep 1

       	# Instantiate NIFI Template 3.x
       	echo "*********************************Instantiating NIFI Flow..."
       	curl -u admin:admin -i -H "Content-Type:application/json" -d "{\"templateId\":\"$TEMPLATEID\",\"originX\":100,\"originY\":100}" -X POST http://$NIFI_HOST:9090/nifi-api/process-groups/root/template-instance
       	sleep 1

       	# Rename NIFI Root Group HDF 3.x
       	echo "*********************************Renaming Nifi Root Group..."
       	ROOT_GROUP_REVISION=$(curl -X GET http://$NIFI_HOST:9090/nifi-api/process-groups/root |grep -Po '\"version\":([0-9]+)'|grep -Po '([0-9]+)')

       	sleep 1
       	ROOT_GROUP_ID=$(curl -X GET http://$NIFI_HOST:9090/nifi-api/process-groups/root|grep -Po '("component":{"id":")([0-9a-zA-z\-]+)'| grep -Po '(:"[0-9a-zA-z\-]+)'| grep -Po '([0-9a-zA-z\-]+)')

       	PAYLOAD=$(echo "{\"id\":\"$ROOT_GROUP_ID\",\"revision\":{\"version\":$ROOT_GROUP_REVISION},\"component\":{\"id\":\"$ROOT_GROUP_ID\",\"name\":\"$TEMPLATE_NAME\"}}")

       	sleep 1
       	curl -d $PAYLOAD  -H "Content-Type: application/json" -X PUT http://$NIFI_HOST:9090/nifi-api/process-groups/$ROOT_GROUP_ID

}

configureNifiTempate () {
	GROUP_TARGETS=$(curl -u admin:admin -i -X GET http://$AMBARI_HOST:9090/nifi-api/process-groups/root/process-groups | grep -Po '\"uri\":\"([a-z0-9-://.]+)' | grep -Po '(?!.*\")([a-z0-9-://.]+)')
    length=${#GROUP_TARGETS[@]}
    echo $length
    echo ${GROUP_TARGETS[0]}

    #for ((i = 0; i < $length; i++))
    for GROUP in $GROUP_TARGETS
    do
       	#CURRENT_GROUP=${GROUP_TARGETS[i]}
       	CURRENT_GROUP=$GROUP
       	echo "***********************************************************calling handle ports with group $CURRENT_GROUP"
       	handleGroupPorts $CURRENT_GROUP
       	echo "***********************************************************calling handle processors with group $CURRENT_GROUP"
       	handleGroupProcessors $CURRENT_GROUP
       	echo "***********************************************************done handle processors"
    done

    ROOT_TARGET=$(curl -u admin:admin -i -X GET http://$AMBARI_HOST:9090/nifi-api/process-groups/root| grep -Po '\"uri\":\"([a-z0-9-://.]+)' | grep -Po '(?!.*\")([a-z0-9-://.]+)')

    handleGroupPorts $ROOT_TARGET

    handleGroupProcessors $ROOT_TARGET
}

handleGroupProcessors (){
       	TARGET_GROUP=$1

       	TARGETS=($(curl -u admin:admin -i -X GET $TARGET_GROUP/processors | grep -Po '\"uri\":\"([a-z0-9-://.]+)' | grep -Po '(?!.*\")([a-z0-9-://.]+)'))
       	length=${#TARGETS[@]}
       	echo $length
       	echo ${TARGETS[0]}

       	for ((i = 0; i < $length; i++))
       	do
       		ID=$(curl -u admin:admin -i -X GET ${TARGETS[i]} |grep -Po '"id":"([a-zA-z0-9\-]+)'|grep -Po ':"([a-zA-z0-9\-]+)'|grep -Po '([a-zA-z0-9\-]+)'|head -1)
       		REVISION=$(curl -u admin:admin -i -X GET ${TARGETS[i]} |grep -Po '\"version\":([0-9]+)'|grep -Po '([0-9]+)')
       		TYPE=$(curl -u admin:admin -i -X GET ${TARGETS[i]} |grep -Po '"type":"([a-zA-Z0-9\-.]+)' |grep -Po ':"([a-zA-Z0-9\-.]+)' |grep -Po '([a-zA-Z0-9\-.]+)' |head -1)
       		echo "Current Processor Path: ${TARGETS[i]}"
       		echo "Current Processor Revision: $REVISION"
       		echo "Current Processor ID: $ID"
       		echo "Current Processor TYPE: $TYPE"

       			if ! [ -z $(echo $TYPE|grep "Record") ]; then
       				echo "***************************This is a Record Processor"

       				RECORD_READER=$(curl -u admin:admin -i -X GET ${TARGETS[i]} |grep -Po '"record-reader":"[a-zA-Z0-9-]+'|grep -Po ':"[a-zA-Z0-9-]+'|grep -Po '[a-zA-Z0-9-]+'|head -1)
                RECORD_WRITER=$(curl -u admin:admin -i -X GET ${TARGETS[i]} |grep -Po '"record-writer":"[a-zA-Z0-9-]+'|grep -Po ':"[a-zA-Z0-9-]+'|grep -Po '[a-zA-Z0-9-]+'|head -1)

                echo "Record Reader: $RECORD_READER"
                echo "Record Writer: $RECORD_WRITER"

       				SCHEMA_REGISTRY=$(curl -u admin:admin -i -X GET http://$AMBARI_HOST:9090/nifi-api/controller-services/$RECORD_READER |grep -Po '"schema-registry":"[a-zA-Z0-9-]+'|grep -Po ':"[a-zA-Z0-9-]+'|grep -Po '[a-zA-Z0-9-]+'|head -1)

       				echo "Schema Registry: $SCHEMA_REGISTRY"

       				curl -u admin:admin -i -H "Content-Type:application/json" -X PUT -d "{\"id\":\"$SCHEMA_REGISTRY\",\"revision\":{\"version\":$REVISION},\"component\":{\"id\":\"$SCHEMA_REGISTRY\",\"state\":\"ENABLED\",\"properties\":{\"url\":\"http:\/\/$AMBARI_HOST:7788\/api\/v1\"}}}" http://$AMBARI_HOST:9090/nifi-api/controller-services/$SCHEMA_REGISTRY

       				curl -u admin:admin -i -H "Content-Type:application/json" -X PUT -d "{\"id\":\"$RECORD_READER\",\"revision\":{\"version\":$REVISION},\"component\":{\"id\":\"$RECORD_READER\",\"state\":\"ENABLED\"}}" http://$AMBARI_HOST:9090/nifi-api/controller-services/$RECORD_READER

       				curl -u admin:admin -i -H "Content-Type:application/json" -X PUT -d "{\"id\":\"$RECORD_WRITER\",\"revision\":{\"version\":$REVISION},\"component\":{\"id\":\"$RECORD_WRITER\",\"state\":\"ENABLED\"}}" http://$AMBARI_HOST:9090/nifi-api/controller-services/$RECORD_WRITER

       			fi
       		if ! [ -z $(echo $TYPE|grep "PutKafka") ] || ! [ -z $(echo $TYPE|grep "PublishKafka") ]; then
       			echo "***************************This is a PutKafka Processor"
       			echo "***************************Updating Kafka Broker Porperty and Activating Processor..."
       			if ! [ -z $(echo $TYPE|grep "PutKafka") ]; then
                    PAYLOAD=$(echo "{\"id\":\"$ID\",\"revision\":{\"version\":$REVISION},\"component\":{\"id\":\"$ID\",\"config\":{\"properties\":{\"Known Brokers\":\"$AMBARI_HOST:6667\"}},\"state\":\"RUNNING\"}}")
                else
                    PAYLOAD=$(echo "{\"id\":\"$ID\",\"revision\":{\"version\":$REVISION},\"component\":{\"id\":\"$ID\",\"config\":{\"properties\":{\"bootstrap.servers\":\"$AMBARI_HOST:6667\"}},\"state\":\"RUNNING\"}}")
                fi
       		else
       			echo "***************************Activating Processor..."
       				PAYLOAD=$(echo "{\"id\":\"$ID\",\"revision\":{\"version\":$REVISION},\"component\":{\"id\":\"$ID\",\"state\":\"RUNNING\"}}")
       			fi
       		echo "$PAYLOAD"

       		curl -u admin:admin -i -H "Content-Type:application/json" -d "${PAYLOAD}" -X PUT ${TARGETS[i]}
       	done
}

handleGroupPorts (){
       	TARGET_GROUP=$1

       	TARGETS=($(curl -u admin:admin -i -X GET $TARGET_GROUP/output-ports | grep -Po '\"uri\":\"([a-z0-9-://.]+)' | grep -Po '(?!.*\")([a-z0-9-://.]+)'))
       	length=${#TARGETS[@]}
       	echo $length
       	echo ${TARGETS[0]}

       	for ((i = 0; i < $length; i++))
       	do
       		ID=$(curl -u admin:admin -i -X GET ${TARGETS[i]} |grep -Po '"id":"([a-zA-z0-9\-]+)'|grep -Po ':"([a-zA-z0-9\-]+)'|grep -Po '([a-zA-z0-9\-]+)'|head -1)
       		REVISION=$(curl -u admin:admin -i -X GET ${TARGETS[i]} |grep -Po '\"version\":([0-9]+)'|grep -Po '([0-9]+)')
       		TYPE=$(curl -u admin:admin -i -X GET ${TARGETS[i]} |grep -Po '"type":"([a-zA-Z0-9\-.]+)' |grep -Po ':"([a-zA-Z0-9\-.]+)' |grep -Po '([a-zA-Z0-9\-.]+)' |head -1)
       		echo "Current Processor Path: ${TARGETS[i]}"
       		echo "Current Processor Revision: $REVISION"
       		echo "Current Processor ID: $ID"

       		echo "***************************Activating Port ${TARGETS[i]}..."

       		PAYLOAD=$(echo "{\"id\":\"$ID\",\"revision\":{\"version\":$REVISION},\"component\":{\"id\":\"$ID\",\"state\": \"RUNNING\"}}")

       		echo "PAYLOAD"
       		curl -u admin:admin -i -H "Content-Type:application/json" -d "${PAYLOAD}" -X PUT ${TARGETS[i]}
       	done
}

createSAMCluster() {
	#Import cluster
	export CLUSTER_ID=$(curl -H "content-type:application/json" -X POST http://$AMBARI_HOST:7777/api/v1/catalog/clusters -d '{"name":"'$CLUSTER_NAME'","description":"Demo Cluster","ambariImportUrl":"http://'$AMBARI_HOST':8080/api/v1/clusters/'$CLUSTER_NAME'"}'| grep -Po '\"id\":([0-9]+)'|grep -Po '([0-9]+)')

	#Import cluster config
	curl -H "content-type:application/json" -X POST http://$AMBARI_HOST:7777/api/v1/catalog/cluster/import/ambari -d '{"clusterId":'$CLUSTER_ID',"ambariRestApiRootUrl":"http://'$AMBARI_HOST':8080/api/v1/clusters/'$CLUSTER_NAME'","password":"admin","username":"admin"}'
}

initializeSAMNamespace () {
	#Initialize New Namespace
	export NAMESPACE_ID=$(curl -H "content-type:application/json" -X POST http://$AMBARI_HOST:7777/api/v1/catalog/namespaces -d '{"name":"dev","description":"dev","streamingEngine":"STORM"}'| grep -Po '\"id\":([0-9]+)'|grep -Po '([0-9]+)')

	#Add Services to Namespace
	curl -H "content-type:application/json" -X POST http://$AMBARI_HOST:7777/api/v1/catalog/namespaces/$NAMESPACE_ID/mapping/bulk -d '[{"clusterId":'$CLUSTER_ID',"serviceName":"STORM","namespaceId":'$NAMESPACE_ID'},{"clusterId":'$CLUSTER_ID',"serviceName":"HDFS","namespaceId":'$NAMESPACE_ID'},{"clusterId":'$CLUSTER_ID',"serviceName":"HBASE","namespaceId":'$NAMESPACE_ID'},{"clusterId":'$CLUSTER_ID',"serviceName":"KAFKA","namespaceId":'$NAMESPACE_ID'},{"clusterId":'$CLUSTER_ID',"serviceName":"DRUID","namespaceId":'$NAMESPACE_ID'},{"clusterId":'$CLUSTER_ID',"serviceName":"HDFS","namespaceId":'$NAMESPACE_ID'},{"clusterId":'$CLUSTER_ID',"serviceName":"HIVE","namespaceId":'$NAMESPACE_ID'},{"clusterId":'$CLUSTER_ID',"serviceName":"ZOOKEEPER","namespaceId":'$NAMESPACE_ID'}]'
}

uploadSAMExtensions() {
	#Import UDF and UDAF
	cd $ROOT_PATH/sam-custom-extensions/sam-custom-udf/
	mvn clean package
	mvn assembly:assembly

	curl -F udfJarFile=@$ROOT_PATH/sam-custom-extensions/sam-custom-udf/target/sam-custom-udf-0.0.5.jar -F 'udfConfig={"name":"TIMESTAMP_LONG","displayName":"TIMESTAMP_LONG","description":"Converts a String timestamp to Timestamp Long","type":"FUNCTION","className":"hortonworks.hdf.sam.custom.udf.time.ConvertToTimestampLong"};type=application/json' -X POST http://$AMBARI_HOST:7777/api/v1/catalog/streams/udfs

	curl -F udfJarFile=@$ROOT_PATH/sam-custom-extensions/sam-custom-udf/target/sam-custom-udf-0.0.5.jar -F 'udfConfig={"name":"GET_WEEK","displayName":"GET_WEEK","description":"For a given data time string, returns week of the input date","type":"FUNCTION","className":"hortonworks.hdf.sam.custom.udf.time.GetWeek"};type=application/json' -X POST http://$AMBARI_HOST:7777/api/v1/catalog/streams/udfs

	#Import Custom Processors
	cd $ROOT_PATH/sam-custom-extensions/sam-custom-processor
	mvn clean package -DskipTests
	mvn assembly:assembly -DskipTests

	curl -sS -X POST -i -F jarFile=@$ROOT_PATH/sam-custom-extensions/sam-custom-processor/target/sam-custom-processor-0.0.5-jar-with-dependencies.jar http://$AMBARI_HOST:7777/api/v1/catalog/streams/componentbundles/PROCESSOR/custom -F customProcessorInfo=@$ROOT_PATH/sam-custom-extensions/sam-custom-processor/src/main/resources/phoenix-enrich-truck-demo.json

	curl -sS -X POST -i -F jarFile=@$ROOT_PATH/sam-custom-extensions/sam-custom-processor/target/sam-custom-processor-0.0.5.jar http://$AMBARI_HOST:7777/api/v1/catalog/streams/componentbundles/PROCESSOR/custom -F customProcessorInfo=@$ROOT_PATH/sam-custom-extensions/sam-custom-processor/src/main/resources/enrich-weather.json
	
	cp $ROOT_PATH/sam-custom-extensions/sam-custom-processor/target/sam-custom-processor-0.0.5.jar $ROOT_PATH/sam-custom-extensions/sam-custom-processor/target/sam-custom-processor-0.0.5a.jar 

	curl -sS -X POST -i -F jarFile=@$ROOT_PATH/sam-custom-extensions/sam-custom-processor/target/sam-custom-processor-0.0.5a.jar http://$AMBARI_HOST:7777/api/v1/catalog/streams/componentbundles/PROCESSOR/custom -F customProcessorInfo=@$ROOT_PATH/sam-custom-extensions/sam-custom-processor/src/main/resources/normalize-model-features.json
}

importPMMLModel () {
	MODEL_DIR=$1
	MODEL_FILE=$2
	MODEL_NAME=$3
	#Import PMML Model
	echo pmmlFile=@$MODEL_DIR'/'$MODEL_FILE_-F_'modelInfo={"name":"'$MODEL_NAME'","namespace":"ml_model","uploadedFileName":"'$MODEL_FILE'"};type=text/json'-X_POST_http://$AMBARI_HOST:7777/api/v1/catalog/ml/models
	
	curl -sS -i -F pmmlFile=@$MODEL_DIR'/'$MODEL_FILE -F 'modelInfo={"name":"'$MODEL_NAME'","namespace":"ml_model","uploadedFileName":"'$MODEL_FILE'"};type=text/json' -X POST http://$AMBARI_HOST:7777/api/v1/catalog/ml/models
}

importSAMTopology () {
	SAM_DIR=$1
	TOPOLOGY_NAME=$2
	#Import Topology
	sed -r -i 's;\{\{HOST1\}\};'$AMBARI_HOST';g' $SAM_DIR
	sed -r -i 's;\{\{CLUSTERNAME\}\};'$CLUSTER_NAME';g' $SAM_DIR
 
	export TOPOLOGY_ID=$(curl -F file=@$SAM_DIR -F 'topologyName='$TOPOLOGY_NAME -F 'namespaceId='$NAMESPACE_ID -X POST http://$AMBARI_HOST:7777/api/v1/catalog/topologies/actions/import| grep -Po '\"id\":([0-9]+)'|grep -Po '([0-9]+)')

    echo $TOPOLOGY_ID
}

deploySAMTopology () {
	TOPOLOGY_ID=$1
	
	#Deploy Topology
	echo "********** curl -X POST http://$AMBARI_HOST:7777/api/v1/catalog/topologies/$TOPOLOGY_ID/versions/$TOPOLOGY_ID/actions/deploy"
	curl -X POST http://$AMBARI_HOST:7777/api/v1/catalog/topologies/$TOPOLOGY_ID/versions/$TOPOLOGY_ID/actions/deploy
	
	#Poll Deployment State until deployment completes or fails
	echo "curl -X GET http://$AMBARI_HOST:7777/api/v1/catalog/topologies/$TOPOLOGY_ID/deploymentstate"
	TOPOLOGY_STATUS=$(curl -X GET http://$AMBARI_HOST:7777/api/v1/catalog/topologies/$TOPOLOGY_ID/deploymentstate | grep -Po '"name":"([A-Z_]+)'| grep -Po '([A-Z_]+)')
    sleep 2
    echo "TOPOLOGY STATUS: $TOPOLOGY_STATUS"
    LOOPESCAPE="false"
    if ! [[ "$TOPOLOGY_STATUS" == TOPOLOGY_STATE_DEPLOYED || "$TOPOLOGY_STATUS" == TOPOLOGY_STATE_DEPLOYMENT_FAILED ]]; then
    	until [ "$LOOPESCAPE" == true ]; do
            TOPOLOGY_STATUS=$(curl -X GET http://$AMBARI_HOST:7777/api/v1/catalog/topologies/$TOPOLOGY_ID/deploymentstate | grep -Po '"name":"([A-Z_]+)'| grep -Po '([A-Z_]+)')
            if [[ "$TOPOLOGY_STATUS" == TOPOLOGY_STATE_DEPLOYED || "$TOPOLOGY_STATUS" == TOPOLOGY_STATE_DEPLOYMENT_FAILED ]]; then
                LOOPESCAPE="true"
            fi
            echo "*********************************TOPOLOGY STATUS: $TOPOLOGY_STATUS"
            sleep 2
        done
    fi
}

pushSchemasToRegistry (){
			
PAYLOAD="{\"name\":\"truck_events_log\",\"type\":\"avro\",\"schemaGroup\":\"truck-sensors-log\",\"description\":\"truck_events_log\",\"evolve\":true,\"compatibility\":\"BACKWARD\"}"

	curl -u admin:admin -i -H "content-type: application/json" -d "$PAYLOAD" -X POST http://$AMBARI_HOST:7788/api/v1/schemaregistry/schemas
	
	PAYLOAD="{\"schemaText\":\"{\\\"type\\\":\\\"record\\\",\\\"namespace\\\":\\\"hortonworks.hdp.refapp.trucking\\\",\\\"name\\\":\\\"truckgeoevent\\\",\\\"fields\\\":[{\\\"name\\\":\\\"eventTime\\\",\\\"type\\\":\\\"string\\\"},{\\\"name\\\":\\\"eventSource\\\",\\\"type\\\":\\\"string\\\"},{\\\"name\\\":\\\"truckId\\\",\\\"type\\\":\\\"int\\\"},{ \\\"name\\\":\\\"driverId\\\",\\\"type\\\":\\\"int\\\"},{\\\"name\\\":\\\"driverName\\\",\\\"type\\\":\\\"string\\\"},{ \\\"name\\\":\\\"routeId\\\",\\\"type\\\":\\\"int\\\"},{\\\"name\\\":\\\"route\\\",\\\"type\\\":\\\"string\\\"},{\\\"name\\\" :\\\"eventType\\\",\\\"type\\\":\\\"string\\\"},{\\\"name\\\":\\\"latitude\\\",\\\"type\\\":\\\"double\\\"},{\\\"name\\\" :\\\"longitude\\\",\\\"type\\\":\\\"double\\\"},{ \\\"name\\\":\\\"correlationId\\\",\\\"type\\\":\\\"long\\\"}]}\",\"description\":\"truck_events_log\"}"

echo $PAYLOAD
	
	curl -u admin:admin -i -H "content-type: application/json" -d "$PAYLOAD" -X POST http://$AMBARI_HOST:7788/api/v1/schemaregistry/schemas/truck_events_log/versions
	
	PAYLOAD="{\"name\":\"truck_speed_events_log\",\"type\":\"avro\",\"schemaGroup\":\"truck-sensors-log\",\"description\":\"truck_speed_events_log\",\"evolve\":true,\"compatibility\":\"BACKWARD\"}"
	
	curl -u admin:admin -i -H "content-type: application/json" -d "$PAYLOAD" -X POST http://$AMBARI_HOST:7788/api/v1/schemaregistry/schemas
		
	PAYLOAD="{\"schemaText\":\"{\\\"type\\\" : \\\"record\\\",\\\"namespace\\\" : \\\"hortonworks.hdp.refapp.trucking\\\",\\\"name\\\" : \\\"truckspeedevent\\\",\\\"fields\\\" : [{ \\\"name\\\" : \\\"eventTime\\\" , \\\"type\\\" : \\\"string\\\" },{ \\\"name\\\" : \\\"eventSource\\\" , \\\"type\\\" : \\\"string\\\" },{ \\\"name\\\" : \\\"truckId\\\" , \\\"type\\\" : \\\"int\\\" },{ \\\"name\\\" : \\\"driverId\\\" , \\\"type\\\" : \\\"int\\\"},{ \\\"name\\\" : \\\"driverName\\\" , \\\"type\\\" : \\\"string\\\"},{ \\\"name\\\" : \\\"routeId\\\" , \\\"type\\\" : \\\"int\\\"},{ \\\"name\\\" : \\\"route\\\" , \\\"type\\\" : \\\"string\\\"},{ \\\"name\\\" : \\\"speed\\\" , \\\"type\\\" : \\\"int\\\"}]}\",\"description\":\"truck_speed_events_log\"}"

echo $PAYLOAD

	curl -u admin:admin -i -H "content-type: application/json" -d "$PAYLOAD" -X POST http://$AMBARI_HOST:7788/api/v1/schemaregistry/schemas/truck_speed_events_log/versions
	
	PAYLOAD="{\"name\":\"truck_events_avro\",\"type\":\"avro\",\"schemaGroup\":\"truck-sensors-log\",\"description\":\"truck_events_log\",\"evolve\":true,\"compatibility\":\"BACKWARD\"}"
	
	curl -u admin:admin -i -H "content-type: application/json" -d "$PAYLOAD" -X POST http://$AMBARI_HOST:7788/api/v1/schemaregistry/schemas
	
	PAYLOAD="{\"schemaText\":\"{\\\"type\\\" : \\\"record\\\",\\\"namespace\\\" : \\\"hortonworks.hdp.refapp.trucking\\\",\\\"name\\\" : \\\"truckgeoeventkafka\\\",\\\"fields\\\" : [{ \\\"name\\\" : \\\"eventTime\\\" , \\\"type\\\" : \\\"string\\\" },{ \\\"name\\\" : \\\"eventSource\\\" , \\\"type\\\" : \\\"string\\\" },{ \\\"name\\\" : \\\"truckId\\\" , \\\"type\\\" : \\\"int\\\" },{ \\\"name\\\" : \\\"driverId\\\" , \\\"type\\\" : \\\"int\\\"},{ \\\"name\\\" : \\\"driverName\\\" , \\\"type\\\" : \\\"string\\\"},{ \\\"name\\\" : \\\"routeId\\\" , \\\"type\\\" : \\\"int\\\"},{ \\\"name\\\" : \\\"route\\\" , \\\"type\\\" : \\\"string\\\"},{ \\\"name\\\" : \\\"eventType\\\" , \\\"type\\\" : \\\"string\\\"},{ \\\"name\\\" : \\\"latitude\\\" , \\\"type\\\" : \\\"double\\\"},{ \\\"name\\\" : \\\"longitude\\\" , \\\"type\\\" : \\\"double\\\"},{ \\\"name\\\" : \\\"correlationId\\\" , \\\"type\\\" : \\\"long\\\"},{\\\"name\\\" : \\\"geoAddress\\\", \\\"type\\\" : \\\"string\\\"}]}\",\"description\":\"truck_events_log\"}"

echo $PAYLOAD
	
	curl -u admin:admin -i -H "content-type: application/json" -d "$PAYLOAD" -X POST http://$AMBARI_HOST:7788/api/v1/schemaregistry/schemas/truck_events_avro/versions
	
PAYLOAD="{\"name\":\"truck_speed_events_avro\",\"type\":\"avro\",\"schemaGroup\":\"truck-sensors-log\",\"description\":\"truck_speed_events_avro\",\"evolve\":true,\"compatibility\":\"BACKWARD\"}"
	
	curl -u admin:admin -i -H "content-type: application/json" -d "$PAYLOAD" -X POST http://$AMBARI_HOST:7788/api/v1/schemaregistry/schemas
	
	PAYLOAD="{\"schemaText\": \"{\\\"type\\\" : \\\"record\\\",\\\"namespace\\\" : \\\"hortonworks.hdp.refapp.trucking\\\",\\\"name\\\" : \\\"truckspeedevent\\\",\\\"fields\\\" : [{ \\\"name\\\" : \\\"eventTime\\\" , \\\"type\\\" : \\\"string\\\" },{ \\\"name\\\" : \\\"eventSource\\\" , \\\"type\\\" : \\\"string\\\" },{ \\\"name\\\" : \\\"truckId\\\" , \\\"type\\\" : \\\"int\\\" },{ \\\"name\\\" : \\\"driverId\\\" , \\\"type\\\" : \\\"int\\\"},{ \\\"name\\\" : \\\"driverName\\\" , \\\"type\\\" : \\\"string\\\"},{ \\\"name\\\" : \\\"routeId\\\" , \\\"type\\\" : \\\"int\\\"},{ \\\"name\\\" : \\\"route\\\" , \\\"type\\\" : \\\"string\\\"},{ \\\"name\\\" : \\\"speed\\\" , \\\"type\\\" : \\\"int\\\"}   ]}\",\"description\":\"truck_speed_events_avro\"}"

echo $PAYLOAD
	
	curl -u admin:admin -i -H "content-type: application/json" -d "$PAYLOAD" -X POST http://$AMBARI_HOST:7788/api/v1/schemaregistry/schemas/truck_speed_events_avro/versions
	
}

createHbaseTables () {
	#Create Hbase Tables
	echo "create 'driver_speed','0'" | hbase shell
	echo "create 'driver_violations','0'" | hbase shell
}

createPhoenixTables () {
	DATA_FOLDER=$1
	#Create Phoenix Tables
	tee create_tables.sql <<-'EOF'
CREATE TABLE IF NOT EXISTS timesheet (
 driverid BIGINT NOT NULL,
 week BIGINT NOT NULL,
 hours_logged BIGINT,
 miles_logged BIGINT,
 CONSTRAINT pk PRIMARY KEY (driverid,week));

CREATE TABLE IF NOT EXISTS drivers (
 driverid BIGINT NOT NULL,
 name VARCHAR(50),
 certified CHAR(1),
 wage_plan VARCHAR(50),
 CONSTRAINT pk PRIMARY KEY (driverid));
EOF
	/usr/hdp/current/phoenix-client/bin/sqlline.py $ZK_HOST:2181:/hbase-unsecure create_tables.sql 
	/usr/hdp/current/phoenix-client/bin/psql.py -t DRIVERS $DATA_FOLDER/drivers.csv
	/usr/hdp/current/phoenix-client/bin/psql.py -t TIMESHEET $DATA_FOLDER/timesheet.csv
}

createKafkaTopics () {
	/usr/hdp/current/kafka-broker/bin/kafka-topics.sh --zookeeper $ZK_HOST:2181 --create --topic truck_events_avro --partitions 1 --replication-factor 1

/usr/hdp/current/kafka-broker/bin/kafka-topics.sh --zookeeper $ZK_HOST:2181 --create --topic truck_speed_events_avro --partitions 1 --replication-factor 1

}

createStormView () {
	STORMUI_HOST=$(getStormUIHost)

	curl -u admin:admin -H "X-Requested-By:ambari" -X POST -d '{"ViewInstanceInfo":{"instance_name":"Storm_View","label":"Storm View","visible":true,"icon_path":"","icon64_path":"","description":"storm view","properties":{"storm.host":"'$STORMUI_HOST'","storm.port":"8744","storm.sslEnabled":"false"},"cluster_type":"NONE"}}' http://$AMBARI_HOST:8080/api/v1/views/Storm_Monitoring/versions/0.1.0/instances/Storm_View

}

exec > >(tee -i /root/demo-install.log)
exec 2>&1

export ROOT_PATH=~
echo "*********************************ROOT PATH IS: $ROOT_PATH"

export AMBARI_HOST=$(hostname -f)
echo "*********************************AMABRI HOST IS: $AMBARI_HOST"

export CLUSTER_NAME=$(curl -u admin:admin -X GET http://$AMBARI_HOST:8080/api/v1/clusters |grep cluster_name|grep -Po ': "(.+)'|grep -Po '[a-zA-Z0-9\-_!?.]+')

if [[ -z $CLUSTER_NAME ]]; then
        echo "Could not connect to Ambari Server. Please run the install script on the same host where Ambari Server is installed."
        exit 1
else
       	echo "*********************************CLUSTER NAME IS: $CLUSTER_NAME"
fi

export VERSION=`hdp-select status hadoop-client | sed 's/hadoop-client - \([0-9]\.[0-9]\).*/\1/'`
export INTVERSION=$(echo $VERSION*10 | bc | grep -Po '([0-9][0-9])')
echo "*********************************HDP VERSION IS: $VERSION"

export HADOOP_USER_NAME=hdfs
echo "*********************************HADOOP_USER_NAME set to HDFS"

echo "********************************* Capturing Service Endpoint in the Environment"
captureEnvironment
echo "********************************* Creating Hbase Tables"
createHbaseTables
echo "********************************* Creating Phoenix Tables"
createPhoenixTables $ROOT_PATH/CloudBreakArtifacts/recipes/TRUCKING_DEMO_CONTROL/package/data
echo "********************************* Creating Kafka Topics"
createKafkaTopics
echo "********************************* Create Storm View"
createStormView
echo "********************************* Registering Schemas"
pushSchemasToRegistry	
echo "********************************* Deploying Nifi Template"
deployTemplateToNifi $ROOT_PATH/CloudBreakArtifacts/recipes/TRUCKING_DEMO_CONTROL/package/nifi/trucking-demo.xml Trucking-Demo
echo "********************************* Configuring Nifi Template"
configureNifiTempate
echo "********************************* Creating SAM Service Pool"
createSAMCluster
echo "********************************* Initializing SAM Namespace"
initializeSAMNamespace
echo "********************************* Uploading SAM Extensions"
uploadSAMExtensions
echo "********************************* Import PMML Model to SAM"
importPMMLModel $ROOT_PATH/CloudBreakArtifacts/recipes/TRUCKING_DEMO_CONTROL/package/model truck_demo_pmml.xml truck_demo_pmml 
echo "********************************* Import SAM Template"
TOPOLOGY_ID=$(importSAMTopology $ROOT_PATH/CloudBreakArtifacts/recipes/TRUCKING_DEMO_CONTROL/package/sam/trucking-demo.json Trucking-Demo)
echo "********************************* Deploy SAM Topology"
deploySAMTopology "$TOPOLOGY_ID"	
