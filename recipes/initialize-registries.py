#!/usr/bin/python

import requests, json, sys, socket, time, subprocess, os, pwd
from requests.auth import HTTPBasicAuth

ambari_admin_user = 'admin'
ambari_admin_password = 'admin-password1'

ambari_clusters_uri = '/api/v1/clusters'
ambari_services_uri = '/api/v1/services'

scripts_repo_config_name = 'scripts.repo.name'

schema_registry_api_uri = '/api/v1'
schema_registry_schemas_uri = '/schemaregistry/schemas'
schema_registry_schemas_orderbook_versions_uri = '/orderbook/versions'

nifi_api_uri = '/nifi-api'
nifi_controller_uri = '/controller'
nifi_root_group_uri = '/root'
nifi_process_groups_uri = '/process-groups'
nifi_remote_process_groups_uri = '/remote-process-groups'

nifi_client_id = 'recipe'

nifi_registry_user = 'nifiregistry'
nifi_registry_dir =  '/var/lib/nifi-registry'
nifi_registry_config_section_name = 'nifi-registry-properties'
nifi_registry_git_repo_url = 'https://github.com/vakshorton/nifi-flow-registry.git'
nifi_registry_git_repo_dir = '/home/nifiregistry'
nifi_registry_git_repo_url_config_name = 'nifi.registry.git.repo.url'
nifi_registry_storage_bucket_config_name = 'nifi.registry.storage.bucket'

nifi_master_component_name = 'NIFI_MASTER'
nifi_registry_service_name = 'NIFI_REGISTRY'
schema_registry_service_name = 'REGISTRY'
nifi_registry_component_name = 'NIFI_REGISTRY_MASTER'
schema_registry_component_name = 'REGISTRY_SERVER'

zk_port = '2181'
ambari_port = '8080'
nifi_master_port = '9090'
nifi_registry_port = '61080'
schema_registry_port = '7788'

host_name = socket.getfqdn()
host_ip = socket.gethostbyname(socket.gethostname())

headers={'content-type':'application/json'}
ambari_cluster_name = json.loads(requests.get('http://'+host_name+':'+ambari_port+ambari_clusters_uri, auth=HTTPBasicAuth(ambari_admin_user, ambari_admin_password)).content)['items'][0]['Clusters']['cluster_name']

def check_external_argument(ambari_config_section_name, argument_name):
    try:
        get_latest_config(ambari_config_section_name)[argument_name]
        return True
    except KeyError, e:
        print ambari_config_section_name + ' - ' + argument_name + ' is null'  #make sure the property has been configured in Ambari under ' + dps_host_config_file
        return False

def get_component_host(target_component):
    component_host_name = 'unknown'
    headers={'content-type':'application/x-www-form-urlencoded','X-Requested-By':'ambari'}
    host_services = json.loads(requests.get('http://'+host_name+':'+ambari_port+ambari_clusters_uri+'/'+ambari_cluster_name+'/hosts?fields=host_components/HostRoles/service_name', auth=HTTPBasicAuth(ambari_admin_user, ambari_admin_password)).content)['items']
    for host in host_services:
        host_components = host['host_components']
        for component in host_components:
            component_name = component['HostRoles']['component_name']
            if component_name == target_component:
                component_host_name = component['HostRoles']['host_name']
                return component_host_name
    
    return component_host_name

def get_latest_config(config_name):
    headers={'content-type':'application/x-www-form-urlencoded','X-Requested-By':'ambari'}    
    
    tag = json.loads(requests.get('http://'+host_name+':'+ambari_port+ambari_clusters_uri+'/'+ambari_cluster_name+'?fields=Clusters/desired_configs', auth=HTTPBasicAuth(ambari_admin_user, ambari_admin_password)).content)['Clusters']['desired_configs'][config_name]['tag']
    config = json.loads(requests.get('http://'+host_name+':'+ambari_port+ambari_clusters_uri+'/'+ambari_cluster_name+'/configurations?type='+config_name+'&tag='+tag, auth=HTTPBasicAuth(ambari_admin_user, ambari_admin_password)).content)['items'][0]['properties']
    return config

def get_schema_def(schema_path):
    with open(schema_path) as schema_read:
        schema = json.dumps(json.load(schema_read))
    
    return schema

def upload_schema_to_registry(schema_name):
    scripts_repo_name = get_latest_config(nifi_registry_config_section_name)[scripts_repo_config_name]
    schemas_path = '/root/'+scripts_repo_name+'/schema/'
    
    print 'Creating schema '+schema_name + '...'
    headers={'content-type':'application/json'}
    payload='{"name":"'+schema_name+'","type":"avro","schemaGroup":"'+schema_name+'","description":"'+schema_name+'","evolve":true,"compatibility":"BACKWARD"}'
    print 'Sending ' + payload + " --> " + schema_registry_url+schema_registry_api_uri+schema_registry_schemas_uri
    result = requests.post(url=schema_registry_url+schema_registry_api_uri+schema_registry_schemas_uri,data=payload, headers=headers, verify=False)
    print 'result: ' + str(result.status_code)+' - '+result.content
    print 'Loading schema definition...'
    
    payload = '{"schemaText":'+json.dumps(get_schema_def(schemas_path+schema_name+'.avsc'))+',"description":"'+schema_name+'"}'
    print 'Sending ' + payload + " --> " + schema_registry_url+schema_registry_api_uri+schema_registry_schemas_uri+schema_registry_schemas_orderbook_versions_uri
    result = requests.post(url=schema_registry_url+schema_registry_api_uri+schema_registry_schemas_uri+schema_registry_schemas_orderbook_versions_uri,data=payload, headers=headers, verify=False)
    print 'result: ' + str(result.status_code)+' - '+result.content

def stop_service(service_name):
    headers={'content-type':'application/x-www-form-urlencoded','X-Requested-By':'ambari'}
    result = json.loads(requests.get('http://'+host_name+':'+ambari_port+ambari_clusters_uri+'/'+ambari_cluster_name+'/services/'+service_name, auth=HTTPBasicAuth(ambari_admin_user, ambari_admin_password), headers=headers, verify=False).content)
    
    if result['ServiceInfo']['state'] == 'STARTED' :
      print 'Requesting STOP task'
      print 'Current Service State: ' + result['ServiceInfo']['state']
      payload = '{"RequestInfo": {"context": "Stop '+service_name+'"}, "ServiceInfo": {"state": "INSTALLED"}}'
      result = json.loads(requests.put('http://'+host_name+':'+ambari_port+ambari_clusters_uri+'/'+ambari_cluster_name+'/services/'+service_name, auth=HTTPBasicAuth(ambari_admin_user, ambari_admin_password), data=payload, headers=headers, verify=False).content)
      print result
      stop_request_id = str(result['Requests']['id'])
      result = json.loads(requests.get('http://'+host_name+':'+ambari_port+ambari_clusters_uri+'/'+ambari_cluster_name+'/requests/' + stop_request_id, auth=HTTPBasicAuth(ambari_admin_user, ambari_admin_password), data=payload, headers=headers, verify=False).content)
      print 'Current Task Status: ' + result['Requests']['request_status']
      while result['Requests']['request_status'] != 'COMPLETED':
        stop_request_id = str(result['Requests']['id'])
        result = json.loads(requests.get('http://'+host_name+':'+ambari_port+ambari_clusters_uri+'/'+ambari_cluster_name+'/requests/' + stop_request_id, auth=HTTPBasicAuth(ambari_admin_user, ambari_admin_password), data=payload, headers=headers, verify=False).content)
        print 'Current Task Status: ' + result['Requests']['request_status']
        time.sleep(2)

def start_service(service_name):
    headers={'content-type':'application/x-www-form-urlencoded','X-Requested-By':'ambari'}
    result = json.loads(requests.get('http://'+host_name+':'+ambari_port+ambari_clusters_uri+'/'+ambari_cluster_name+'/services/'+service_name, auth=HTTPBasicAuth(ambari_admin_user, ambari_admin_password), headers=headers, verify=False).content)
    
    if result['ServiceInfo']['state'] == 'INSTALLED' :
      print 'Requesting START task'
      payload = '{"RequestInfo": {"context": "Start '+service_name+'"}, "ServiceInfo": {"state": "STARTED"}}'
      result = json.loads(requests.put('http://'+host_name+':'+ambari_port+ambari_clusters_uri+'/'+ambari_cluster_name+'/services/'+service_name, auth=HTTPBasicAuth(ambari_admin_user, ambari_admin_password), data=payload, headers=headers, verify=False).content)
      print result
      start_request_id = str(result['Requests']['id'])
      result = json.loads(requests.get('http://'+host_name+':'+ambari_port+ambari_clusters_uri+'/'+ambari_cluster_name+'/requests/' + start_request_id, auth=HTTPBasicAuth(ambari_admin_user, ambari_admin_password), data=payload, headers=headers, verify=False).content)
      print 'Current Task Status: ' + result['Requests']['request_status']
      while result['Requests']['request_status'] != 'COMPLETED':
        start_request_id = str(result['Requests']['id'])
        result = json.loads(requests.get('http://'+host_name+':'+ambari_port+ambari_clusters_uri+'/'+ambari_cluster_name+'/requests/' + start_request_id, auth=HTTPBasicAuth(ambari_admin_user, ambari_admin_password), data=payload, headers=headers, verify=False).content)
        print 'Current Task Status: ' + result['Requests']['request_status']    
        time.sleep(2)

def restart_service(service_name):
    print 'Restarting '+service_name+' to activate changes...'
    
    stop_service(service_name)
    start_service(service_name)

def configure_nifi_registry_client():
    print 'Creating Nifi Registry client...'
    headers={'content-type':'application/json'}
    payload = '{"revision": {"clientId": "'+nifi_client_id+'","version": 0},"component": {"name": "nifi-registry-client","uri": "http://'+nifi_registry_host+':'+nifi_registry_port+'","description": ""}}'
    print 'Sending ' + payload + " --> " + nifi_master_url+nifi_api_uri+nifi_controller_uri+'/registry-clients'
    result = requests.post(url=nifi_master_url+nifi_api_uri+nifi_controller_uri+'/registry-clients',data=payload, headers=headers, verify=False)
    print 'result: ' + str(result.status_code)+' - '+result.content

def create_self_reference_remote_group():
    print 'Creating Nifi Registry client...'
    headers={'content-type':'application/json'}
    payload = '{"revision": {"clientId": "'+nifi_client_id+'","version": 0},"component": {"targetUris": "http://'+nifi_master_host+':'+nifi_master_port+'/nifi","position": {"x": 482,"y": 342},"communicationsTimeout": "30 sec","yieldDuration": "10 sec","transportProtocol": "HTTP"}}'
    print 'Sending ' + payload + " --> " + nifi_master_url+nifi_api_uri+nifi_process_groups_uri+nifi_root_group_uri+nifi_remote_process_groups_uri
    result = requests.post(url=nifi_master_url+nifi_api_uri+nifi_process_groups_uri+nifi_root_group_uri+nifi_remote_process_groups_uri,data=payload, headers=headers, verify=False)
    print 'result: ' + str(result.status_code)+' - '+result.content

def git_clone_nifi_registry_repo():
    nifi_registry_user_id = pwd.getpwnam(nifi_registry_user).pw_uid
    nifi_registry_git_repo_url = get_latest_config(nifi_registry_config_section_name)[nifi_registry_git_repo_url_config_name]
    os.chdir(nifi_registry_git_repo_dir)
    subprocess.check_output(["git", "clone", nifi_registry_git_repo_url])
    for root, dirs, files in os.walk(nifi_registry_git_repo_dir):
        for dir in dirs:
            os.chown(os.path.join(root, dir), nifi_registry_user_id, nifi_registry_user_id)
        for file in files:
            os.chown(os.path.join(root, file), nifi_registry_user_id, nifi_registry_user_id)

def load_nifi_registry_from_storage_bucket():
    nifi_registry_storage_bucket = get_latest_config(nifi_registry_config_section_name)[nifi_registry_storage_bucket_config_name]
    nifi_registry_s3 = 's3://'+nifi_registry_storage_bucket+'/nifi-registry'
    print 'Loading nifi registry from S3 storage... ' + nifi_registry_s3 +' --> ' + nifi_registry_dir
    subprocess.check_output(["aws", "s3", "cp", nifi_registry_s3, nifi_registry_dir, "--recursive"])
    restart_service(nifi_registry_service_name)

nifi_master_host = get_component_host(nifi_master_component_name)
nifi_registry_host = get_component_host(nifi_registry_component_name)
schema_registry_host = get_component_host(schema_registry_component_name)

schema_registry_url = 'http://'+schema_registry_host+':'+schema_registry_port
nifi_master_url = 'http://'+nifi_master_host+':'+nifi_master_port 

if check_external_argument(nifi_registry_config_section_name, nifi_registry_git_repo_url_config_name):
    git_clone_nifi_registry_repo()

if check_external_argument(nifi_registry_config_section_name, nifi_registry_storage_bucket_config_name):
    load_nifi_registry_from_storage_bucket()

if check_external_argument(nifi_registry_config_section_name, scripts_repo_config_name):
    upload_schema_to_registry('orderbook')

#create_self_reference_remote_group()
configure_nifi_registry_client()
