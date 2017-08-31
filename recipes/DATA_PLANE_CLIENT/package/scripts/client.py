import sys, os, pwd, signal, time, shutil, requests, json
from subprocess import *
from resource_management import *

class DataPlaneClient(Script):
  def install(self, env):
    self.configure(env)
    import params
    Execute('echo Show Params variables')
    Execute('echo list of config dump: ' + str(', '.join(params.list_of_configs)))
    Execute('echo master config dump: ' + str(', '.join(params.master_configs)))
    Execute('echo host level config dump: ' + str(', '.join(params.list_of_host_level_params)))
    Execute('echo java home: ' + params.jdk64_home)
    Execute('echo ambari host: ' + params.ambari_server_host)
    Execute('echo cluster name: ' + params.cluster_name)
    Execute('echo namenode host: ' + params.namenode_host)
    Execute('echo namenode port: ' + params.namenode_port)
    Execute('echo hive metastore uri: ' + params.hive_metastore_uri)
    Execute('echo hbase zookeeper: ' + params.hbase_zookeeper)
    Execute('echo atlas host: ' + params.atlas_host)
    Execute('echo kafka host: ' + params.kafka_broker_host)
    Execute('echo kafka port: ' + params.kafka_port)
    
    if params.nifi_exists_code == '200':
        Execute('echo nifi host: ' + params.nifi_host)
        Execute('echo nifi port: ' + params.nifi_port)
    
    Execute('echo stack_version: ' + params.stack_version_unformatted)
    
    Execute('echo data plane ambari host: ' + params.data_plane_ambari_host)
    Execute('echo data plane cluster name: ' + params.data_plane_cluster_name)
    Execute('echo data plane namenode host: ' + params.data_plane_namenode_host)
    Execute('echo data plane zookeeper host: ' + params.data_plane_zookeeper_host)
    Execute('echo data plane meta store uri: ' + params.data_plane_hive_metastore_uri)
    Execute('echo data plane hive server host: ' + params.data_plane_hive_server_host)
    Execute('echo data plane atlas host: ' + params.data_plane_atlas_host)
    Execute('echo data plane kafka host: ' + params.data_plane_kafka_host)
    Execute('echo Download Data Plane Util Bits')
    if not os.path.exists(params.install_dir):
        os.makedirs(params.install_dir)
    
    if os.path.exists(params.install_dir+'/Utils'):
        shutil.rmtree(params.install_dir+'/Utils')
    os.chdir(params.install_dir)
    Execute('git clone ' + params.download_url)
    
    Execute('echo Creating Ranger Hive Service for this cluster in Data Plane')
    print requests.post('http://'+params.data_plane_ranger_host+':'+params.ranger_port+'/service/public/v2/api/service', auth=('admin', 'admin'),headers={'content-type':'application/json'},data=('{"isEnabled":true,"type":"hive","name":"'+params.data_plane_ranger_hive_repo+'","description":"","tagService":"data-plane-tag","configs":{"jdbc.url":"jdbc:hive2://'+params.data_plane_hive_server_host+':'+params.hive_server_port+'","jdbc.driverClassName":"org.apache.hive.jdbc.HiveDriver","username":"hive","password":"*****"}}')).content
    
    #{"isEnabled":true,"service":"biologics-demo_hive","name":"all - database, table, column","policyType":0,"description":"Policy for all - database, table, column","isAuditEnabled":true,"resources":{"column":{"values":["*"],"isExcludes":false,"isRecursive":false},"table":{"values":["*"],"isExcludes":false,"isRecursive":false},"database":{"values":["*"],"isExcludes":false,"isRecursive":false}},"policyItems":[{"accesses":[{"type":"select","isAllowed":true},{"type":"update","isAllowed":true},{"type":"create","isAllowed":true},{"type":"drop","isAllowed":true},{"type":"alter","isAllowed":true},{"type":"index","isAllowed":true},{"type":"lock","isAllowed":true},{"type":"all","isAllowed":true}],"users":["hive","admin"],"groups":[],"conditions":[],"delegateAdmin":true}],"denyPolicyItems":[],"allowExceptions":[],"denyExceptions":[],"dataMaskPolicyItems":[],"rowFilterPolicyItems":[]}
    
    Execute('echo Install and configure Ranger Hive Plugin')
    Execute('echo Modify configuration files')
    src_dir = params.install_dir+'/Utils/DATA_PLANE_CLIENT/package/configuration'
    
    Execute('sed -r -i "s;\{\{ZK_HOST\}\};'+params.data_plane_zookeeper_host+';" '+ src_dir+'/ranger-hive-audit.xml')
    Execute('sed -r -i "s;\{\{NAMENODE_HOST\}\};'+params.data_plane_namenode_host+';" '+ src_dir+'/ranger-hive-audit.xml')
    Execute('sed -r -i "s;\{\{RANGER_URL\}\};http://'+params.data_plane_ranger_host+':'+params.ranger_port+';" '+ src_dir+'/ranger-hive-security.xml')
    Execute('sed -r -i "s;\{\{REPO_NAME\}\};'+params.data_plane_ranger_hive_repo+';" '+ src_dir+'/ranger-hive-security.xml')

    Execute('sed -r -i "s;\{\{ZK_HOST\}\};'+params.data_plane_zookeeper_host+';" '+ src_dir+'/ranger-hive-audit')
    Execute('sed -r -i "s;\{\{NAMENODE_HOST\}\};'+params.data_plane_namenode_host+';" '+ src_dir+'/ranger-hive-audit')
    Execute('sed -r -i "s;\{\{RANGER_URL\}\};http://'+params.data_plane_ranger_host+':'+params.ranger_port+';" '+ src_dir+'/ranger-hive-security')
    Execute('sed -r -i "s;\{\{REPO_NAME\}\};'+params.data_plane_ranger_hive_repo+';" '+ src_dir+'/ranger-hive-security')
    
    Execute('echo Copying configuration files to Hive Server conf directory')
    dest_dir = ('/usr/hdp/current/hive-server2/conf/conf.server')
    hiveserver_log = ('/var/log/hive/hiveserver2.log')
    if os.path.exists(dest_dir) and os.path.exists(hiveserver_log):
        src_files = os.listdir(src_dir)
        for file_name in src_files:
            full_file_name = os.path.join(src_dir, file_name)
            if (os.path.isfile(full_file_name)):
                shutil.copy(full_file_name, dest_dir)
    
    dest_dir = ('/usr/hdp/current/hive-server2-hive2/conf/conf.server/')
    hiveserver_log = ('/var/log/hive/hiveserver2Interactive.log')
    if os.path.exists(dest_dir) and os.path.exists(hiveserver_log):
        src_files = os.listdir(src_dir)
        for file_name in src_files:
            full_file_name = os.path.join(src_dir, file_name)
            if (os.path.isfile(full_file_name)):
                shutil.copy(full_file_name, dest_dir)
                
    Execute('echo Setting Hive Plugin configuration')
    config_sh = params.install_dir+'/Utils/DATA_PLANE_CLIENT/package/scripts/configs.sh'
    Execute(config_sh+' set '+params.ambari_server_host+' '+params.cluster_name+' hive-site hive.security.authorization.enabled true')

    Execute(config_sh+' set '+params.ambari_server_host+' '+params.cluster_name+' hive-site hive.conf.restricted.list hive.security.authorization.enabled,hive.security.authorization.manager,hive.security.authenticator.manager')

    Execute(config_sh+' set '+params.ambari_server_host+' '+params.cluster_name+' hiveserver2-site hive.security.authorization.enabled true')

    Execute(config_sh+' set '+params.ambari_server_host+' '+params.cluster_name+' hiveserver2-site hive.security.authorization.manager org.apache.ranger.authorization.hive.authorizer.RangerHiveAuthorizerFactory')

    Execute(config_sh+' set '+params.ambari_server_host+' '+params.cluster_name+' hiveserver2-site hive.security.authenticator.manager org.apache.hadoop.hive.ql.security.SessionStateUserAuthenticator')
    
    Execute(config_sh+' set '+params.ambari_server_host+' '+params.cluster_name+' ranger-hive-audit '+ src_dir+'/ranger-hive-audit')

    Execute(config_sh+' set '+params.ambari_server_host+' '+params.cluster_name+' ranger-hive-plugin-properties '+ src_dir+'/ranger-hive-plugin-properties')

    Execute(config_sh+' set '+params.ambari_server_host+' '+params.cluster_name+' ranger-hive-policymgr-ssl '+ src_dir+'/ranger-hive-policymgr-ssl')

    Execute(config_sh+' set '+params.ambari_server_host+' '+params.cluster_name+' ranger-hive-security '+ src_dir+'/ranger-hive-security')

    Execute('echo Setting Hive Atlas Client Configuration...')
    Execute(config_sh+' set '+params.ambari_server_host+' '+params.cluster_name+' hive-site "atlas.rest.address" "'+params.data_plane_atlas_host+':'+params.atlas_port+'"')

    Execute(config_sh+' set '+params.ambari_server_host+' '+params.cluster_name+' hive-site "atlas.cluster.name" "'+params.data_plane_cluster_name+'"')

    Execute(config_sh+' set '+params.ambari_server_host+' '+params.cluster_name+' application-properties "atlas.cluster.name" "'+params.data_plane_cluster_name+'"')

    Execute(config_sh+' set '+params.ambari_server_host+' '+params.cluster_name+' hive-atlas-application.properties "atlas.kafka.bootstrap.servers" "'+params.data_plane_kafka_host+':'+params.kafka_port+'"')

    Execute(config_sh+' set '+params.ambari_server_host+' '+params.cluster_name+' hive-atlas-application.properties "atlas.kafka.zookeeper.connect" "'+params.data_plane_zookeeper_host+':'+params.zookeeper_port+'"')

    if params.storm_exists_code == '200':
        Execute('echo Setting Storm Atlas Client Configuration...')
        Execute(config_sh+' set '+params.ambari_server_host+' '+params.cluster_name+' storm-atlas-application.properties "atlas.rest.address" "'+params.data_plane_atlas_host+':'+params.atlas_port+'"')
        Execute(config_sh+' set '+params.ambari_server_host+' '+params.cluster_name+' storm-atlas-application.properties "atlas.cluster.name" "'+params.data_plane_cluster_name+'"')
        Execute(config_sh+' set '+params.ambari_server_host+' '+params.cluster_name+' storm-atlas-application.properties "atlas.kafka.zookeeper.connect" "'+params.data_plane_zookeeper_host+':'+params.zookeeper_port+'"')
        Execute(config_sh+' set '+params.ambari_server_host+' '+params.cluster_name+' storm-atlas-application.properties "atlas.kafka.bootstrap.servers" "'+params.data_plane_kafka_host+':'+params.kafka_port+'"')

    if params.sqoop_exists_code == '200':
        Execute('echo Setting Sqoop Atlas Client Configuration...')
        Execute(config_sh+' set '+params.ambari_server_host+' '+params.cluster_name+' sqoop-atlas-application.properties "atlas.rest.address" "'+params.data_plane_atlas_host+':'+params.atlas_port+'"')
        Execute(config_sh+' set '+params.ambari_server_host+' '+params.cluster_name+' sqoop-atlas-application.properties "atlas.cluster.name" "'+params.data_plane_cluster_name+'"')
        Execute(config_sh+' set '+params.ambari_server_host+' '+params.cluster_name+' sqoop-atlas-application.properties "atlas.kafka.zookeeper.connect" "'+params.data_plane_zookeeper_host+':'+params.zookeeper_port+'"')
        Execute(config_sh+' set '+params.ambari_server_host+' '+params.cluster_name+' sqoop-atlas-application.properties "atlas.kafka.bootstrap.servers" "'+params.data_plane_kafka_host+':'+params.kafka_port+'"')

    Execute('echo Setting Hive Meta Store Configuration...')
    Execute(config_sh+' set '+params.ambari_server_host+' '+params.cluster_name+' hive-site "javax.jdo.option.ConnectionURL" "jdbc:mysql://'+params.data_plane_hive_server_host+'/hive?createDatabaseIfNotExist=true"')

    Execute(config_sh+' set '+params.ambari_server_host+' '+params.cluster_name+' hive-site "javax.jdo.option.ConnectionPassword" "hive"')

    Execute(config_sh+' set '+params.ambari_server_host+' '+params.cluster_name+' hive-site "hive.metastore.uris" "'+params.data_plane_hive_metastore_uri+'"')

    if params.spark_exists_code == '200':
        Execute(config_sh+' set '+params.ambari_server_host+' '+params.cluster_name+' spark-hive-site-override "hive.metastore.uris" "'+params.data_plane_hive_metastore_uri+'"')

    Execute('echo Configuring Data Storage and Keys...')
    Execute(config_sh+' set '+params.ambari_server_host+' '+params.cluster_name+' hive-site "hive.metastore.warehouse.dir" "'+params.s3_warehouse+'/apps/hive/warehouse"')
    
    Execute(config_sh+' set '+params.ambari_server_host+' '+params.cluster_name+' core-site "fs.s3a.access.key" "'+params.aws_key+'"')
    
    Execute(config_sh+' set '+params.ambari_server_host+' '+params.cluster_name+' core-site "fs.s3a.secret.key" "'+params.aws_secret+'"')
    
#    Execute(config_sh+' set '+params.ambari_server_host+' '+params.cluster_name+' core-site "fs.default.name" "hdfs://'+params.data_plane_namenode_host+':'+params.namenode_port+'"')

#    Execute(config_sh+' set '+params.ambari_server_host+' '+params.cluster_name+' core-site "fs.defaultFS" "hdfs://'+params.data_plane_namenode_host+':'+params.namenode_port+'"')
#    #requests.put('http://'+params.ambari_server_host+':'+params.ambari_server_port+'/api/v1/clusters/'+params.cluster_name+'/services/HIVE', auth=('admin', 'admin'),headers={'X-Requested-By':'ambari'},data=('{"RequestInfo": {"context": "Stop HIVE"}, "ServiceInfo": {"state": "INSTALLED"}}'))
#        time.sleep(2)
#        #requests.put('http://'+params.ambari_server_host+':'+params.ambari_server_port+'/api/v1/clusters/'+params.cluster_name+'/services/STORM', auth=('admin', 'admin'),headers={'X-Requested-By':'ambari'},data=('{"RequestInfo": {"context": "Stop STORM"}, "ServiceInfo": {"state": "INSTALLED"}}'))
#        time.sleep(2)
#        #requests.put('http://'+params.ambari_server_host+':'+params.ambari_server_port+'/api/v1/clusters/'+params.cluster_name+'/services/HBASE', auth=('admin', 'admin'),headers={'X-Requested-By':'ambari'},data=('{"RequestInfo": {"context": "Stop HBASE"}, "ServiceInfo": {"state": "INSTALLED"}}'))
#        time.sleep(2)
#        #requests.put('http://'+params.ambari_server_host+':'+params.ambari_server_port+'/api/v1/clusters/'+params.cluster_name+'/services/HDFS', auth=('admin', 'admin'),headers={'X-Requested-By':'ambari'},data=('{"RequestInfo": {"context": "Stop HDFS"}, "ServiceInfo": {"state": "INSTALLED"}}'))
#        time.sleep(2)
#        #requests.put('http://'+params.ambari_server_host+':'+params.ambari_server_port+'/api/v1/clusters/'+params.cluster_name+'/services/YARN', auth=('admin', 'admin'),headers={'X-Requested-By':'ambari'},data=('{"RequestInfo": {"context": "Stop YARN"}, "ServiceInfo": {"state": "INSTALLED"}}'))
#        time.sleep(2)
#        #requests.put('http://'+params.ambari_server_host+':'+params.ambari_server_port+'/api/v1/clusters/'+params.cluster_name+'/services/SPARK', auth=('admin', 'admin'),headers={'X-Requested-By':'ambari'},data=('{"RequestInfo": {"context": "Stop SPARK"}, "ServiceInfo": {"state": "INSTALLED"}}'))
#        time.sleep(2)
#        #requests.put('http://'+params.ambari_server_host+':'+params.ambari_server_port+'/api/v1/clusters/'+params.cluster_name+'/services/HDFS', auth=('admin', 'admin'),headers={'X-Requested-By':'ambari'},data=('{"RequestInfo": {"context": "Start HDFS"}, "ServiceInfo": {"state": "STARTED"}}'))
#        time.sleep(2)
#        #requests.put('http://'+params.ambari_server_host+':'+params.ambari_server_port+'/api/v1/clusters/'+params.cluster_name+'/services/YARN', auth=('admin', 'admin'),headers={'X-Requested-By':'ambari'},data=('{"RequestInfo": {"context": "Start YARN"}, "ServiceInfo": {"state": "STARTED"}}'))
#        time.sleep(2)
#        #requests.put('http://'+params.ambari_server_host+':'+params.ambari_server_port+'/api/v1/clusters/'+params.cluster_name+'/services/HBASE', auth=('admin', 'admin'),headers={'X-Requested-By':'ambari'},data=('{"RequestInfo": {"context": "Start HBASE"}, "ServiceInfo": {"state": "STARTED"}}'))
#        time.sleep(2)
#        #requests.put('http://'+params.ambari_server_host+':'+params.ambari_server_port+'/api/v1/clusters/'+params.cluster_name+'/services/HIVE', auth=('admin', 'admin'),headers={'X-Requested-By':'ambari'},data=('{"RequestInfo": {"context": "Start HIVE"}, "ServiceInfo": {"state": "STARTED"}}'))
#        time.sleep(5)
#        #requests.put('http://'+params.ambari_server_host+':'+params.ambari_server_port+'/api/v1/clusters/'+params.cluster_name+'/services/STORM', auth=('admin', 'admin'),headers={'X-Requested-By':'ambari'},data=('{"RequestInfo": {"context": "Start STORM"}, "ServiceInfo": {"state": "STARTED"}}'))
#        time.sleep(1)
#        #requests.put('http://'+params.ambari_server_host+':'+params.ambari_server_port+'/api/v1/clusters/'+params.cluster_name+'/services/SPARK', auth=('admin', 'admin'),headers={'X-Requested-By':'ambari'},data=('{"RequestInfo": {"context": "Start SPARK"}, "ServiceInfo": {"state": "STARTED"}}'))
        
  def status(self, env):
    raise ClientComponentHasNoStatus()

  def configure(self, env):
    import params
    env.set_params(params)

  def data_plane_synch(self, env):
    import params
    env.set_params(params)
    os.chdir(params.demo_install_dir)
    Execute('. ~/.bash_profile')
    Execute('env')
    Execute(params.demo_install_dir+'/redeployApplication.sh '+params.nifi_host+' '+params.nifi_port+' '+params.data_plane_atlas_host+' '+params.atlas_port+' '+params.hive_server_host+' '+params.hive_server_port+' '+params.cluster_name+' &>> redeploy.log')

  def holder():
    Execute('echo Restarting Services to refresh configurations...')
    #import startService
    #import stopService
    #stopService('HIVE',params.ambari_server_host,params.ambari_server_port,params.cluster_name)
    service_status = str(json.loads(requests.get('http://'+params.ambari_server_host+':'+params.ambari_server_port+'/api/v1/clusters/'+params.cluster_name+'/services/HIVE', auth=('admin', 'admin')).content).get('ServiceInfo').get('state'))
    if service_status == 'STARTED':
        task_id = str(json.loads(requests.put('http://'+params.ambari_server_host+':'+params.ambari_server_port+'/api/v1/clusters/'+params.cluster_name+'/services/HIVE', auth=('admin', 'admin'),headers={'X-Requested-By':'ambari'},data=('{"RequestInfo": {"context": "Stop HIVE"}, "ServiceInfo": {"state": "INSTALLED"}}')).content).get('Requests').get('id'))
        loop_escape = False
        while loop_escape != True:
            task_status = str(json.loads(requests.get('http://'+params.ambari_server_host+':'+params.ambari_server_port+'/api/v1/clusters/'+params.cluster_name+'/requests/'+task_id, auth=('admin', 'admin')).content).get('Requests').get('request_status'))
            if task_status == 'COMPLETED':
                loop_escape = True
                time.sleep(2)
            Execute('echo Stop Service HIVE Task Status '+task_status)
        Execute('echo Service HIVE Stopped...')
    elif service_status == 'INSTALLED':
        Execute('echo Service HIVE Already Stopped')
    time.sleep(2)
    #stopService('STORM',params.ambari_server_host,params.ambari_server_port,params.cluster_name)
    
    service_status = str(json.loads(requests.get('http://'+params.ambari_server_host+':'+params.ambari_server_port+'/api/v1/clusters/'+params.cluster_name+'/services/STORM', auth=('admin', 'admin')).content).get('ServiceInfo').get('state'))
    if service_status == 'STARTED':
        task_id = str(json.loads(requests.put('http://'+params.ambari_server_host+':'+params.ambari_server_port+'/api/v1/clusters/'+params.cluster_name+'/services/STORM', auth=('admin', 'admin'),headers={'X-Requested-By':'ambari'},data=('{"RequestInfo": {"context": "Stop STORM"}, "ServiceInfo": {"state": "INSTALLED"}}')).content).get('Requests').get('id'))
        loop_escape = False
        while loop_escape != True:
            task_status = str(json.loads(requests.get('http://'+params.ambari_server_host+':'+params.ambari_server_port+'/api/v1/clusters/'+params.cluster_name+'/requests/'+task_id, auth=('admin', 'admin')).content).get('Requests').get('request_status'))
            if task_status == 'COMPLETED':
                loop_escape = True
                time.sleep(2)
            Execute('echo Stop Service STORM Task Status '+task_status)
        Execute('echo Service STORM Stopped...')
    elif service_status == 'INSTALLED':
        Execute('echo Service STORM Already Stopped')
    time.sleep(2)
    #stopService('SQOOP',params.ambari_server_host,params.ambari_server_port,params.cluster_name)
    service_status = str(json.loads(requests.get('http://'+params.ambari_server_host+':'+params.ambari_server_port+'/api/v1/clusters/'+params.cluster_name+'/services/SQOOP', auth=('admin', 'admin')).content).get('ServiceInfo').get('state'))
    if service_status == 'STARTED':
        task_id = str(json.loads(requests.put('http://'+params.ambari_server_host+':'+params.ambari_server_port+'/api/v1/clusters/'+params.cluster_name+'/services/SQOOP', auth=('admin', 'admin'),headers={'X-Requested-By':'ambari'},data=('{"RequestInfo": {"context": "Stop SQOOP"}, "ServiceInfo": {"state": "INSTALLED"}}')).content).get('Requests').get('id'))
        loop_escape = False
        while loop_escape != True:
            task_status = str(json.loads(requests.get('http://'+params.ambari_server_host+':'+params.ambari_server_port+'/api/v1/clusters/'+params.cluster_name+'/requests/'+task_id, auth=('admin', 'admin')).content).get('Requests').get('request_status'))
            if task_status == 'COMPLETED':
                loop_escape = True
                time.sleep(2)
            Execute('echo Stop Service SQOOP Task Status '+task_status)
        Execute('echo Service SQOOP Stopped...')
    elif service_status == 'INSTALLED':
        Execute('echo Service SQOOP Already Stopped')
    
    time.sleep(1)
    #startService('HIVE',params.ambari_server_host,params.ambari_server_port,params.cluster_name)
    service_status = str(json.loads(requests.get('http://'+params.ambari_server_host+':'+params.ambari_server_port+'/api/v1/clusters/'+params.cluster_name+'/services/HIVE', auth=('admin', 'admin')).content).get('ServiceInfo').get('state'))
    if service_status == 'INSTALLED':
        task_id = str(json.loads(requests.put('http://'+params.ambari_server_host+':'+params.ambari_server_port+'/api/v1/clusters/'+params.cluster_name+'/services/HIVE', auth=('admin', 'admin'),headers={'X-Requested-By':'ambari'},data=('{"RequestInfo": {"context": "Start HIVE"}, "ServiceInfo": {"state": "STARTED"}}')).content).get('Requests').get('id'))
        loop_escape = False
        while loop_escape != True:
            task_status = str(json.loads(requests.get('http://'+params.ambari_server_host+':'+params.ambari_server_port+'/api/v1/clusters/'+params.cluster_name+'/requests/'+task_id, auth=('admin', 'admin')).content).get('Requests').get('request_status'))
            if task_status == 'COMPLETED':
                loop_escape = True
                time.sleep(2)
            Execute('echo Stop Service HIVE Task Status '+task_status)
        Execute('echo Service HIVE started...')
    elif service_status == 'STARTED':
        Execute('echo Service HIVE Already Started')
    time.sleep(2)
    #startService('STORM',params.ambari_server_host,params.ambari_server_port,params.cluster_name)
    service_status = str(json.loads(requests.get('http://'+params.ambari_server_host+':'+params.ambari_server_port+'/api/v1/clusters/'+params.cluster_name+'/services/STORM', auth=('admin', 'admin')).content).get('ServiceInfo').get('state'))
    if service_status == 'INSTALLED':
        task_id = str(json.loads(requests.put('http://'+params.ambari_server_host+':'+params.ambari_server_port+'/api/v1/clusters/'+params.cluster_name+'/services/STORM', auth=('admin', 'admin'),headers={'X-Requested-By':'ambari'},data=('{"RequestInfo": {"context": "Start STORM"}, "ServiceInfo": {"state": "STARTED"}}')).content).get('Requests').get('id'))
        loop_escape = False
        while loop_escape != True:
            task_status = str(json.loads(requests.get('http://'+params.ambari_server_host+':'+params.ambari_server_port+'/api/v1/clusters/'+params.cluster_name+'/requests/'+task_id, auth=('admin', 'admin')).content).get('Requests').get('request_status'))
            if task_status == 'COMPLETED':
                loop_escape = True
                time.sleep(2)
            Execute('echo Stop Service STORM Task Status '+task_status)
        Execute('echo Service STORM started...')
    elif service_status == 'STARTED':
        Execute('echo Service STORM Already Started')
    time.sleep(2)
    #startService('SQOOP',params.ambari_server_host,params.ambari_server_port,params.cluster_name)
    service_status = str(json.loads(requests.get('http://'+params.ambari_server_host+':'+params.ambari_server_port+'/api/v1/clusters/'+params.cluster_name+'/services/SQOOP', auth=('admin', 'admin')).content).get('ServiceInfo').get('state'))
    if service_status == 'INSTALLED':
        task_id = str(json.loads(requests.put('http://'+params.ambari_server_host+':'+params.ambari_server_port+'/api/v1/clusters/'+params.cluster_name+'/services/SQOOP', auth=('admin', 'admin'),headers={'X-Requested-By':'ambari'},data=('{"RequestInfo": {"context": "Start SQOOP"}, "ServiceInfo": {"state": "STARTED"}}')).content).get('Requests').get('id'))
        loop_escape = False
        while loop_escape != True:
            task_status = str(json.loads(requests.get('http://'+params.ambari_server_host+':'+params.ambari_server_port+'/api/v1/clusters/'+params.cluster_name+'/requests/'+task_id, auth=('admin', 'admin')).content).get('Requests').get('request_status'))
            if task_status == 'COMPLETED':
                loop_escape = True
                time.sleep(2)
            Execute('echo Stop Service SQOOP Task Status '+task_status)
        Execute('echo Service SQOOP started...')
    elif service_status == 'STARTED':
        Execute('echo Service SQOOP Already Started')

if __name__ == "__main__":
  DataPlaneClient().execute()
