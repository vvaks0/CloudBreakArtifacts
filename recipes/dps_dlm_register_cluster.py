#!/usr/bin/python

#import requests, json, socket, time, sys, subprocess
#from requests.auth import HTTPBasicAuth
#import sys

#if (len(sys.argv) < 3) or (len(sys.argv) == 4):
#  print 'Need at least 2 argument [is_shared_services, dps_host_name] and at most 4 arguments [target_cluster_name, target_dataset_name]'
#  exit(1)

import requests, json, socket, time, subprocess
from requests.auth import HTTPBasicAuth

#dps_url = 'https://' + sys.argv[2]

dps_admin_user = 'admin'
dps_admin_password = 'admin-password1'
ambari_admin_user = 'admin'
ambari_admin_password = 'admin-password1'
ranger_admin_user = 'admin'
ranger_admin_password = 'admin-password1'

knox_topology = 'dp-proxy'

isDatalake_argument_name = 'dps.cluster.is.datalake'
dpsHost_argument_name = 'dps.host'
partner_cluster_argument_name = 'dlm.initial.partner.cluster'
initial_dataset_argument_name = 'dlm.initial.policy.dataset'

dps_auth_uri = '/auth/in'
dps_identity_uri = '/api/identity'
dps_lakes_uri = '/api/lakes'
dps_sso_provider = '/knox/gateway/knoxsso/api/v1/websso?originalUrl='
dlm_clusters_uri = '/dlm/api/clusters'
dlm_pairs_uri = '/dlm/api/pairs'
dlm_pair_uri = '/dlm/api/pair'
dlm_unpair_uri = '/dlm/api/unpair'
dlm_policies_uri = '/dlm/api/policies?numResults=200'
ambari_clusters_uri = '/api/v1/clusters'
ambari_services_uri = '/api/v1/services'
ranger_servicedef_uri = '/service/public/v2/api/servicedef'
ranger_service_uri = '/service/public/v2/api/service'
ranger_policy_uri = '/service/public/v2/api/policy'
ranger_hive_allpolicy_search_string = 'all%20-%20database,%20table,%20column'

dps_host_config_file = 'beacon-security-site'

zk_port = '2181'
knox_port = '8443'
ranger_port = '6080'
ambari_port = '8080'
atlas_port = '21000'
namenode_port = '8020'

host_name = socket.getfqdn()
host_ip = socket.gethostbyname(socket.gethostname())
ranger_url = 'http://'+host_name+':'+ranger_port

headers={'content-type':'application/json'}

ambari_cluster_name = json.loads(requests.get('http://'+host_name+':'+ambari_port+ambari_clusters_uri, auth=HTTPBasicAuth(ambari_admin_user, ambari_admin_password)).content)['items'][0]['Clusters']['cluster_name']
knox_public_url = json.loads(requests.get('http://'+host_name+':'+ambari_port+ambari_services_uri+'/AMBARI/components/AMBARI_SERVER', auth=HTTPBasicAuth(ambari_admin_user, ambari_admin_password)).content)['RootServiceComponents']['properties']['authentication.jwt.providerUrl'].split(ambari_cluster_name)[0] + ambari_cluster_name
ambari_public_url = knox_public_url + '/' + knox_topology + '/ambari'

def configure_ranger():
    ranger_hive_service_name = ambari_cluster_name + '_hive'
    ranger_knox_service_name = ambari_cluster_name + '_knox'
    ranger_hdfs_service_name = ambari_cluster_name + '_hadoop'
    ranger_atlas_service_name = ambari_cluster_name + '_atlas'
    
    payload = '{"name":"'+ranger_hive_service_name+'","description":"","isEnabled":true,"tagService":"","configs":{"username":"hive","password":"hive","jdbc.driverClassName":"org.apache.hive.jdbc.HiveDriver","jdbc.url":"jdbc:hive2://'+host_name+':'+zk_port+'/;serviceDiscoveryMode=zooKeeper;zooKeeperNamespace=hiveserver2","commonNameForCertificate":""},"type":"hive"}'
    
    ranger_update_result = requests.post(url=ranger_url+ranger_service_uri, auth=HTTPBasicAuth(ranger_admin_user, ranger_admin_password), data=payload, headers=headers, verify=False)
    print ranger_update_result
    if ranger_update_result.status_code == 400:
      print json.loads(ranger_update_result.content)['msgDesc']
    else:
      ranger_hive_service = json.loads(ranger_update_result.content)
      print 'Create Ranger Hive Service: ' + payload
      ranger_hive_service_id = str(ranger_hive_service['id'])
      target_policy = json.loads(requests.get(url=ranger_url+ranger_service_uri+'/'+ranger_hive_service_name+'/policy?policyName='+ranger_hive_allpolicy_search_string, auth=HTTPBasicAuth(ranger_admin_user, ranger_admin_password), data=payload, headers=headers, verify=False).content)[0]
      target_policy['policyItems'][0]['users'].append('beacon')
      target_policy_id = str( target_policy['id'])
      payload = json.dumps(target_policy)
      print 'Add Grant All on Hive Objects to Beacon user : ' + payload
      print 'Result: ' + requests.put(url=ranger_url+ranger_policy_uri+'/'+target_policy_id, auth=HTTPBasicAuth(ranger_admin_user, ranger_admin_password), data=payload, headers=headers, verify=False).content
      
    payload = '{"name":"'+ranger_hdfs_service_name+'","description":"","isEnabled":true,"tagService":"","configs":{"username":"hdfs","password":"hdfs","fs.default.name":"hdfs://'+host_name+':'+namenode_port+'","hadoop.security.authorization":true,"hadoop.security.authentication":"simple","hadoop.security.auth_to_local":"","dfs.datanode.kerberos.principal":"","dfs.namenode.kerberos.principal":"","dfs.secondary.namenode.kerberos.principal":"","hadoop.rpc.protection":"authentication","commonNameForCertificate":""},"type":"hdfs"}'
    
    ranger_update_result = requests.post(url=ranger_url+ranger_service_uri, auth=HTTPBasicAuth(ranger_admin_user, ranger_admin_password), data=payload, headers=headers, verify=False)
    print ranger_update_result
    if ranger_update_result.status_code == 400:
      print json.loads(ranger_update_result.content)['msgDesc']
    else:
      ranger_hdfs_service = json.loads(ranger_update_result.content)
      print 'Create Ranger HDFS Service: ' + payload
      payload = '{"policyType":"0","name":"dpprofiler-audit-read","isEnabled":true,"isAuditEnabled":true,"description":"","resources":{"path":{"values":["/ranger/audit","dpprofiler_default"],"isRecursive":true}},"policyItems":[{"users":["dpprofiler"],"accesses":[{"type":"read","isAllowed":true},{"type":"execute","isAllowed":true}]}],"denyPolicyItems":[],"allowExceptions":[],"denyExceptions":[],"service":"'+ranger_hdfs_service_name+'"}'
      print 'Create dpprofiler-audit-read policy: ' + payload
      print 'Result: ' + requests.post(url=ranger_url+ranger_policy_uri, auth=HTTPBasicAuth(ranger_admin_user, ranger_admin_password), data=payload, headers=headers, verify=False).content
    
    payload = '{"name":"'+ranger_knox_service_name+'","description":"","isEnabled":true,"tagService":"","configs":{"username":"admin","password":"admin","knox.url":"https://'+host_name+':'+knox_port+'","commonNameForCertificate":""},"type":"knox"}'
    ranger_update_result = requests.post(url=ranger_url+ranger_service_uri, auth=HTTPBasicAuth(ranger_admin_user, ranger_admin_password), data=payload, headers=headers, verify=False)
    print ranger_update_result
    if ranger_update_result.status_code == 400:
      print json.loads(ranger_update_result.content)['msgDesc']
    else:
      ranger_knox_service = json.loads(ranger_update_result.content)
      print 'Created Ranger Knox Service...'
    
    payload = '{"name":"'+ranger_atlas_service_name+'","description":"","isEnabled":true,"tagService":"","configs":{"username":"admin","password":"admin","atlas.rest.address":"https://'+host_name+':'+atlas_port+'","commonNameForCertificate":""},"type":"atlas"}'
    ranger_update_result = requests.post(url=ranger_url+ranger_service_uri, auth=HTTPBasicAuth(ranger_admin_user, ranger_admin_password), data=payload, headers=headers, verify=False)
    print ranger_update_result
    if ranger_update_result.status_code == 400:
      print json.loads(ranger_update_result.content)['msgDesc']
    else:
      ranger_atlas_service = json.loads(ranger_update_result.content)
      print 'Created Ranger Atlas Service...'
    
    print 'Waiting for Ranger Policy to take effect...'
    time.sleep(31)

def enable_ranger_special_policies():
    print 'Enable Deny and Exceptions Policies: '
    payload = ''
    result = json.loads(requests.get(url=ranger_url+ranger_servicedef_uri+'/name/hive', auth=HTTPBasicAuth(ranger_admin_user, ranger_admin_password), data=payload, headers=headers, verify=False).content.replace('{ \\"singleValue\\":true }',' ').replace("\'"," "))
    result['policyConditions'] = json.loads('[ {"itemId": 1,"name": "resources-accessed-together", "evaluator": "org.apache.ranger.plugin.conditionevaluator.RangerHiveResourcesAccessedTogetherCondition", "evaluatorOptions": {}, "label": "Resources Accessed Together?", "description": "Resources Accessed Together?" },{ "itemId": 2, "name": "not-accessed-together", "evaluator": "org.apache.ranger.plugin.conditionevaluator.RangerHiveResourcesNotAccessedTogetherCondition", "evaluatorOptions": {}, "label": "Resources Not Accessed Together?", "description": "Resources Not Accessed Together?" } ]')
    result['options'] = json.loads('{"enableDenyAndExceptionsInPolicies":"true"}')
    
    payload = json.dumps(result)
    result = requests.put(url=ranger_url+ranger_servicedef_uri+'/name/hive', auth=HTTPBasicAuth(ranger_admin_user, ranger_admin_password), data=payload, headers=headers, verify=False)
    print result
    return result

def get_latest_config(config_name):
    headers={'content-type':'application/x-www-form-urlencoded','X-Requested-By':'ambari'}    
    
    tag = json.loads(requests.get('http://'+host_name+':'+ambari_port+ambari_clusters_uri+'/'+ambari_cluster_name+'?fields=Clusters/desired_configs', auth=HTTPBasicAuth(ambari_admin_user, ambari_admin_password)).content)['Clusters']['desired_configs'][config_name]['tag']
    config = json.loads(requests.get('http://'+host_name+':'+ambari_port+ambari_clusters_uri+'/'+ambari_cluster_name+'/configurations?type='+config_name+'&tag='+tag, auth=HTTPBasicAuth(ambari_admin_user, ambari_admin_password)).content)['items'][0]['properties']
    return config

def configure_atlas():
    headers={'content-type':'application/x-www-form-urlencoded','X-Requested-By':'ambari'}
    change_description = 'Atlas LDAP Config' 
    target_config_name = 'application-properties'
    config = get_latest_config(target_config_name)
    epoch = str(int(round(time.time() * 1000)))
    payload = json.loads('[{"Clusters":{"desired_config":[{"type":"'+target_config_name+'","tag":"version'+epoch+'","properties":{},"service_config_version_note":"'+change_description+'"}]}}]')
    
    ldap_url = config['atlas.authentication.method.ldap.ad.url']
    ldap_base_dn = config['atlas.authentication.method.ldap.ad.base.dn']
    ldap_bind_dn = config['atlas.authentication.method.ldap.ad.bind.dn']
    ldap_bind_pass = config['atlas.authentication.method.ldap.ad.bind.password']
    ldap_user_DNpattern = 'uid={0}'
    ldap_user_filter = '(&(objectClass=person)(member={0}))'
    ldap_group_filter = '(&(objectClass=groupofnames)(member={0}))'
    ldap_group_searchBase = 'ou=people,dc=hadoop,dc=apache,dc=org'
    
    config['atlas.authentication.method.ldap.url'] = ldap_url
    config['atlas.authentication.method.ldap.base.dn'] = ldap_base_dn
    config['atlas.authentication.method.ldap.bind.dn'] = ldap_bind_dn
    config['atlas.authentication.method.ldap.bind.password'] = ldap_bind_pass
    config['atlas.authentication.method.ldap.userDNpattern'] = ldap_user_DNpattern
    config['atlas.authentication.method.ldap.user.searchfilter'] = ldap_user_filter
    config['atlas.authentication.method.ldap.groupSearchFilter'] = ldap_group_filter
    config['atlas.authentication.method.ldap.groupSearchBase'] = ldap_group_searchBase
    
    payload[0]['Clusters']['desired_config'][0]['properties'] = config
    payload = json.dumps(payload)
    update_result = requests.put('http://'+host_name+':'+ambari_port+ambari_clusters_uri+'/'+ambari_cluster_name, auth=HTTPBasicAuth(ambari_admin_user, ambari_admin_password), data=payload, headers=headers, verify=False)
    print update_result
    print 'Atlas LDAP config updated...'
    return update_result

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
      while result['Requests']['request_status'] == 'IN_PROGRESS':
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
      while result['Requests']['request_status'] == 'IN_PROGRESS':
        start_request_id = str(result['Requests']['id'])
        result = json.loads(requests.get('http://'+host_name+':'+ambari_port+ambari_clusters_uri+'/'+ambari_cluster_name+'/requests/' + start_request_id, auth=HTTPBasicAuth(ambari_admin_user, ambari_admin_password), data=payload, headers=headers, verify=False).content)
        print 'Current Task Status: ' + result['Requests']['request_status']    
        time.sleep(2)

def restart_service(service_name):
    print 'Restarting '+service_name+' to activate changes...'
    
    stop_service(service_name)
    start_service(service_name)
    
def get_dps_token():
    #token = json.loads(requests.post(url = dps_url+dps_auth_uri, data = '{"username":"'+dps_admin_user+'","password":"'+dps_admin_password+'"}', headers=headers, verify=False).text)['token']
    #token = requests.post(url = dps_url+dps_auth_uri, data = '{"username":"'+dps_admin_user+'","password":"'+dps_admin_password+'"}', headers=headers, verify=False).cookies.pop('dp_jwt')
    #token = requests.get(url = dps_url+dps_identity_uri, cookies=cookie, headers=headers, verify=False).cookies.pop('dp_jwt')
    #cookie = {'dp_jwt':token}
    
    token = requests.post(url = dps_url+dps_sso_provider+dps_url, auth=HTTPBasicAuth(dps_admin_user,dps_admin_password), headers=headers, allow_redirects=False, verify=False).cookies.pop('hadoop-jwt')
    cookie = {'hadoop-jwt':token}    
    return cookie

def dps_register_cluster():
    tags = ''
    datacenter = 'DC01'
    location = '7064'
    if is_datalake == 'true':
      tags = '{"name": "shared-services"}'
      datacenter = 'DC02'
      location = '7069'
    
    if check_external_argument(partner_cluster_argument_name) and check_external_argument(initial_dataset_argument_name):
      datacenter = 'DC03'
      location = '7072'
    
    headers={'content-type':'application/json'}
    #payload = '{"allowUntrusted":true,"behindGateway":false,"dcName": "DC02","ambariUrl": "http://'+host_name+':'+ambari_port+'","description":" ","location": 7064,"isDatalake": true,"name": "'+ambari_cluster_name+'","state": "TO_SYNC","ambariIpAddress": "http://'+host_ip+':'+ambari_port+'","properties": {"tags": ['+tags+']}}'
    payload = '{"allowUntrusted":true,"behindGateway":true,"dcName": "'+datacenter+'","ambariUrl": "'+ambari_public_url+'","description":" ","location": '+location+',"isDatalake": true,"name": "'+ambari_cluster_name+'","state": "TO_SYNC","ambariIpAddress": "'+ambari_public_url+'", "knoxEnabled": true, "knoxUrl": "'+knox_public_url+'","properties": {"tags": ['+tags+']}}'
    
    print 'Payload: ' + payload
    result = requests.post(url=dps_url+dps_lakes_uri, cookies=cookie, data=payload, headers=headers, verify=False).content
    print 'Result: ' + result
    
    print 'Waiting for DPS registration to take effect...'
    time.sleep(3)
    
    newClusterId = str(json.loads(result)['id'])
    payload = '{}'
    result = requests.post(url=dps_url+dps_lakes_uri + '/'+ newClusterId + '/sync', data=payload, cookies=cookie, headers=headers, verify=False).content
    print "Sync Result: " + result

def get_dlm_cluster_details(target_cluster_name):
    dlm_clusters = json.loads(requests.get(url=dps_url+dlm_clusters_uri, cookies=cookie, headers=headers, verify=False).content)
    #print dlm_clusters
    for dlm_cluster in dlm_clusters['clusters']:
        #print dlm_cluster['name'] +' ? '+ target_cluster_name
        if dlm_cluster['name'] == target_cluster_name:
            return dlm_cluster
    
    return None
    
def dlm_pair_clusters(source_cluster, destination_cluster):
    headers={'content-type':'application/json'}
    payload = '[{"clusterId": '+str(source_cluster['id'])+',"beaconUrl": "'+source_cluster['beaconUrl']+'"},{"clusterId": '+str(destination_cluster['id'])+',"beaconUrl": "'+destination_cluster['beaconUrl']+'"}]'
    print 'Payload: ' + payload
    print 'Result: ' + requests.post(url=dps_url+dlm_pair_uri, cookies=cookie, data=payload, headers=headers, verify=False).content

def dlm_create_policy(source_cluster, destination_cluster, dataset_name, replicationPolicyName):
    headers={'content-type':'application/json'}
    payload = '{"policyDefinition": {"name": "'+replicationPolicyName+'","type": "HIVE","sourceCluster": "'+source_cluster['dataCenter']+'$'+source_cluster['name']+'","targetCluster": "'+destination_cluster['dataCenter']+'$'+destination_cluster['name']+'","frequencyInSec": 3600,"sourceDataset": "'+dataset_name+'"},"submitType": "SUBMIT_AND_SCHEDULE"}' 
    print 'Payload: ' + payload
    print 'Result: ' + requests.post(url=dps_url+dlm_clusters_uri+'/'+str(destination_cluster['id'])+'/policy/'+replicationPolicyName+'/submit', cookies=cookie, data=payload, headers=headers, verify=False).content

def check_external_argument(argument_name):
    try:
        get_latest_config(dps_host_config_file)[argument_name]
        return True
    except KeyError, e:
        print argument_name + ' is null'  #make sure the property has been configured in Ambari under ' + dps_host_config_file
        return False

##################################################


enable_ranger_special_policies()
#print 'Configure Ranger Services'
#configure_ranger()

print 'Configuring Atlas for LDAP...'
atlas_update_result = configure_atlas()

if atlas_update_result.status_code == 400:
    print json.loads(atlas_update_result.content)['msgDesc']
else:
    restart_service('ATLAS')
 
if not check_external_argument(isDatalake_argument_name):
    exit(1)

print 'Cluster is Datalake? ' 
is_datalake = get_latest_config(dps_host_config_file)['dps.cluster.is.datalake']
print is_datalake

if not check_external_argument(dpsHost_argument_name):
    exit(1)

print 'Getting Auth Token from DPS...'
dps_url = 'https://'+ get_latest_config(dps_host_config_file)[dpsHost_argument_name]
cookie = get_dps_token()

print 'Verifying Token is Valid...'
requests.get(url = dps_url+'/api/knox/status', cookies = cookie, verify=False).content

print 'Registering Cluster with Dataplane: ' + dps_url+dps_lakes_uri
dps_register_cluster()

if check_external_argument(partner_cluster_argument_name) and check_external_argument(initial_dataset_argument_name):
    
    partner_cluster_name= get_latest_config(dps_host_config_file)[partner_cluster_argument_name]
    initial_dataset_name = get_latest_config(dps_host_config_file)[initial_dataset_argument_name]
    
    headers={'content-type':'application/json'}
    print 'Getting Cluster Information from DLM... '
    
    partner_cluster = get_dlm_cluster_details(partner_cluster_name)
    if partner_cluster == None:
        print ambari_cluster_name + ' not found in DLM... cannot complete pairing and replication scheduling'
        exit(1) 
        
    destination_cluster = get_dlm_cluster_details(ambari_cluster_name)
    if destination_cluster == None:  
        print destination_cluster['name'] + ' not found in DLM... cannot complete pairing and replication scheduling'
        exit(1)
        
    print 'Pairing Cluster with Shared Services: ' + dps_url+dlm_pair_uri
    dlm_pair_clusters(partner_cluster, destination_cluster)
    
    replicationPolicyName = 'hive-'+initial_dataset_name+'-'+partner_cluster['name']+'-'+destination_cluster['name']
    print 'Enabling replication policy: ' + replicationPolicyName + ' to: '+dps_url+dlm_clusters_uri+'/'+str(destination_cluster['id'])+'/policy/'+replicationPolicyName+'/submit'
    dlm_create_policy(partner_cluster, destination_cluster, initial_dataset_name, replicationPolicyName)
else:
    print 'Partner Cluster and Initial Dataset NOT defined... skipping DLM configurations'
    if is_datalake == 'false':
        print 'Loading Standard Datasets...'
        subprocess.call("CloudBreakArtifacts/recipes/load-logistics-dataset.sh")
        subprocess.call("CloudBreakArtifacts/recipes/load-hortonia-dataset.py")
