#!/bin/bash

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

echo "*********************************Install Maven..."		
wget http://repos.fedorapeople.org/repos/dchen/apache-maven/epel-apache-maven.repo -O /etc/yum.repos.d/epel-apache-maven.repo
yum install -y apache-maven

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
	echo "*********************************Importing NIFI Template..."		
       	# Import NIFI Template HDF 2.x
       	TEMPLATEID=$(curl -v -F template=@"$ROOT_PATH/CloudBreakArtifacts/hdf-config/nifi-template/truck-nifi-flow-with-record-query.xml" -X POST http://$AMBARI_HOST:9090/nifi-api/process-groups/root/templates/upload | grep -Po '<id>([a-z0-9-]+)' | grep -Po '>([a-z0-9-]+)' | grep -Po '([a-z0-9-]+)')
		sleep 1
		
		# Instantiate NIFI Template 2.x
		echo "*********************************Instantiating NIFI Flow..."
       	curl -u admin:admin -i -H "Content-Type:application/json" -d "{\"templateId\":\"$TEMPLATEID\",\"originX\":100,\"originY\":100}" -X POST http://$AMBARI_HOST:9090/nifi-api/process-groups/root/template-instance
       	sleep 1
       	
       	# Rename NIFI Root Group HDF 2.x
		echo "*********************************Renaming Nifi Root Group..."
		ROOT_GROUP_REVISION=$(curl -X GET http://$AMBARI_HOST:9090/nifi-api/process-groups/root |grep -Po '\"version\":([0-9]+)'|grep -Po '([0-9]+)')
		
		sleep 1
		ROOT_GROUP_ID=$(curl -X GET http://$AMBARI_HOST:9090/nifi-api/process-groups/root|grep -Po '("component":{"id":")([0-9a-zA-z\-]+)'| grep -Po '(:"[0-9a-zA-z\-]+)'| grep -Po '([0-9a-zA-z\-]+)')

		PAYLOAD=$(echo "{\"id\":\"$ROOT_GROUP_ID\",\"revision\":{\"version\":$ROOT_GROUP_REVISION},\"component\":{\"id\":\"$ROOT_GROUP_ID\",\"name\":\"Trucking-Demo\"}}")
		
		sleep 1
		curl -d $PAYLOAD  -H "Content-Type: application/json" -X PUT http://$AMBARI_HOST:9090/nifi-api/process-groups/$ROOT_GROUP_ID
	
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
	
	curl -u admin:admin -i -H "content-type: application/json" -d "$PAYLOAD" -X POST http://$AMBARI_HOST:7788/api/v1/schemaregistry/schemas/truck_events_avro%3Av/versions
	
PAYLOAD="{\"name\":\"truck_speed_events_avro\",\"type\":\"avro\",\"schemaGroup\":\"truck-sensors-log\",\"description\":\"truck_speed_events_avro\",\"evolve\":true,\"compatibility\":\"BACKWARD\"}"
	
	curl -u admin:admin -i -H "content-type: application/json" -d "$PAYLOAD" -X POST http://$AMBARI_HOST:7788/api/v1/schemaregistry/schemas
	
	PAYLOAD="{\"schemaText\": \"{\\\"type\\\" : \\\"record\\\",\\\"namespace\\\" : \\\"hortonworks.hdp.refapp.trucking\\\",\\\"name\\\" : \\\"truckspeedevent\\\",\\\"fields\\\" : [{ \\\"name\\\" : \\\"eventTime\\\" , \\\"type\\\" : \\\"string\\\" },{ \\\"name\\\" : \\\"eventSource\\\" , \\\"type\\\" : \\\"string\\\" },{ \\\"name\\\" : \\\"truckId\\\" , \\\"type\\\" : \\\"int\\\" },{ \\\"name\\\" : \\\"driverId\\\" , \\\"type\\\" : \\\"int\\\"},{ \\\"name\\\" : \\\"driverName\\\" , \\\"type\\\" : \\\"string\\\"},{ \\\"name\\\" : \\\"routeId\\\" , \\\"type\\\" : \\\"int\\\"},{ \\\"name\\\" : \\\"route\\\" , \\\"type\\\" : \\\"string\\\"},{ \\\"name\\\" : \\\"speed\\\" , \\\"type\\\" : \\\"int\\\"}   ]}\",\"description\":\"truck_speed_events_avro\"}"

echo $PAYLOAD
	
	curl -u admin:admin -i -H "content-type: application/json" -d "$PAYLOAD" -X POST http://$AMBARI_HOST:7788/api/v1/schemaregistry/schemas/truck_speed_events_avro%3Av/versions
	
}
	pushSchemasToRegistry

	deployTemplateToNifi
	
	sleep 1
	
    GROUP_TARGETS=$(curl -u admin:admin -i -X GET http://$AMBARI_HOST:9090/nifi-api/process-groups/root/process-groups | grep -Po '\"uri\":\"([a-z0-9-://.]+)' | grep -Po '(?!.*\")([a-z0-9-://.]+)')
    length=${#GROUP_TARGETS[@]}
    echo $length
    echo ${GROUP_TARGETS[0]}

    for ((i = 0; i < $length; i++))
    do
       	CURRENT_GROUP=${GROUP_TARGETS[i]}
       	handleGroupPorts $CURRENT_GROUP
       	echo "***********************************************************calling handle processors with group $CURRENT_GROUP"
       	handleGroupProcessors $CURRENT_GROUP
       	echo "***********************************************************done handle processors"
    done

    ROOT_TARGET=$(curl -u admin:admin -i -X GET http://$AMBARI_HOST:9090/nifi-api/process-groups/root| grep -Po '\"uri\":\"([a-z0-9-://.]+)' | grep -Po '(?!.*\")([a-z0-9-://.]+)')

   handleGroupPorts $ROOT_TARGET

   handleGroupProcessors $ROOT_TARGET