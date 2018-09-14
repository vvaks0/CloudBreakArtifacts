#!/usr/bin/python

import sys, requests, json, socket, time, subprocess
from requests.auth import HTTPBasicAuth

dps_admin_user = 'admin'
dps_admin_password = 'admin-password1'
ambari_admin_user = 'admin'
ambari_admin_password = 'admin-password1'
ranger_admin_user = 'admin'
ranger_admin_password = 'admin-password1'

knox_topology = 'dp-proxy'

dps_auth_uri = '/auth/in'
dps_identity_uri = '/api/identity'
dps_lakes_uri = '/api/lakes'
dps_services_uri = '/api/services'
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

behind_gateway = True

headers={'content-type':'application/json'}
ambari_cluster_name = json.loads(requests.get('http://'+host_name+':'+ambari_port+ambari_clusters_uri, auth=HTTPBasicAuth(ambari_admin_user, ambari_admin_password)).content)['items'][0]['Clusters']['cluster_name']

def get_knox_public_url():
    config = json.loads(requests.get('http://'+host_name+':'+ambari_port+ambari_services_uri+'/AMBARI/components/AMBARI_SERVER', auth=HTTPBasicAuth(ambari_admin_user, ambari_admin_password)).content)
    try:
        knox_public_url = config['RootServiceComponents']['properties']['authentication.jwt.providerUrl'].split(ambari_cluster_name)[0] + ambari_cluster_name
    except KeyError:
        knox_public_url = 'unknown'    
    
    return knox_public_url

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
    current_index = 0
    token_name_list = ['hadoop-jwt','dp-hadoop-jwt']
    cookie = attempt_pop_token(token_name_list, current_index)
            
    return cookie

def attempt_pop_token(token_name_list, current_index):
    cookie_name = token_name_list[current_index]
    print 'attempting to get token with name: ' +  cookie_name
    try:
      token = requests.post(url = dps_url+dps_sso_provider+dps_url, auth=HTTPBasicAuth(dps_admin_user,dps_admin_password), headers=headers, allow_redirects=False, verify=False).cookies.pop(cookie_name)
      cookie_ = {cookie_name:token}
    except KeyError:
      cookie_name = ''
      current_index += 1
      if current_index >= len(token_name_list):
        cookie_ = {'missing':'missing'}
      else:    
        print 'token with name ' + cookie_name + ' was not found, trying next indexed name...' + token_name_list[current_index] 
        token = attempt_pop_token(token_name_list, current_index)
        cookie_ = token
    
    return cookie_

def dps_register_cluster():
    tags = ''
    datacenter = 'DC01'
    location = '7064'
    if is_datalake == 'true':
      tags = '{"name": "shared-services"}'
      datacenter = 'DC02'
      location = '7069'
    
    headers={'content-type':'application/json'}
    
    if behind_gateway:
        payload = '{"allowUntrusted":true,"behindGateway":true,"dcName": "'+datacenter+'","ambariUrl": "'+ambari_public_url+'","description":" ","location": '+location+',"isDatalake": true,"name": "'+ambari_cluster_name+'","clusterType":"HDP","state": "TO_SYNC","ambariIpAddress": "'+ambari_public_url+'", "knoxEnabled": true, "knoxUrl": "'+knox_public_url+'","properties": {"tags": ['+tags+']}}'
    else:
        payload = '{"allowUntrusted":true,"behindGateway":false,"dcName": "DC02","ambariUrl": "http://'+public_ip+':'+ambari_port+'","description":" ","location": '+location+',"isDatalake": true,"name": "'+ambari_cluster_name+'","clusterType":"HDP","state": "TO_SYNC","ambariIpAddress": "http://'+public_ip+':'+ambari_port+'","properties": {"tags": ['+tags+']}}'
    
    print 'Payload: ' + payload
    result = requests.post(url=dps_url+dps_lakes_uri, cookies=cookie, data=payload, headers=headers, verify=False).content
    print 'Result: ' + result
    
    print 'Waiting for DPS registration to take effect...'
    time.sleep(3)
    
    new_cluster_id = str(json.loads(result)['id'])
    payload = '{}'
    result = requests.post(url=dps_url+dps_lakes_uri + '/'+ new_cluster_id + '/sync', data=payload, cookies=cookie, headers=headers, verify=False).content
    print "Sync Result: " + result
    return new_cluster_id

def dps_enable_cluster_services(cluster_id):
    cluster_services = json.loads(requests.get(url=dps_url+dps_lakes_uri + '/'+ cluster_id+'/services', cookies=cookie, headers=headers, verify=False).content)
    for cluster_service in cluster_services:
        print 'Checking service '+str(cluster_service)
        if cluster_service['compatible'] == True and cluster_service['enabled'] == False:
            print 'Enabling service '+cluster_service['sku']['name']+' for cluster_id '+cluster_id
            service_id = str(cluster_service['sku']['id'])
            result = requests.put(url=dps_url+dps_services_uri + '/'+ service_id+'/clusters/'+cluster_id+'/association', cookies=cookie, headers=headers, verify=False).content
            print result

def check_external_argument(argument_name):
    try:
        get_latest_config(dps_host_config_file)[argument_name]
        return True
    except KeyError, e:
        print argument_name + ' is null'  #make sure the property has been configured in Ambari under ' + dps_host_config_file
        return False

##################################################


#enable_ranger_special_policies()

with open('/opt/metadata/dps.json') as f:
    dps_meta_data = json.load(f)

dps_url = 'https://'+str(dps_meta_data['dpsHostPublic'])

print 'Cluster is Datalake? ' 
try:
    is_datalake = get_latest_config(dps_host_config_file)['dps.cluster.is.datalake']
except KeyError:
    is_datalake = 'false'

print is_datalake

print 'Getting Auth Token from DPS...'
cookie = get_dps_token()

print 'Verifying Token is Valid...'
requests.get(url = dps_url+'/api/knox/status', cookies = cookie, verify=False).content

knox_public_url = get_knox_public_url()
if knox_public_url == 'unknown':
    behind_gateway = False
    public_ip = requests.get('http://169.254.169.254/latest/meta-data/public-ipv4', verify=False).content
    knox_public_url = 'https://' + public_ip
    ambari_public_url = 'https://' + public_ip
else:
    behind_gateway = True
    ambari_public_url = knox_public_url + '/' + knox_topology + '/ambari'

print 'Registering Cluster with Dataplane: ' + dps_url+dps_lakes_uri
cluster_id = str(dps_register_cluster())

print 'Checking for compatible services...'
dps_enable_cluster_services(cluster_id)
