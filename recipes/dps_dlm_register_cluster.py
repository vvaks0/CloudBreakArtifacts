#!/usr/bin/python

import requests, json, socket, time, sys
from requests.auth import HTTPBasicAuth

if len(sys.argv) < 2:
  print 'Need at least 1 argument [dps_host_name] and at most 2 arguments [target_cluster_name]'
  exit(1)

dps_admin_user = 'admin'
dps_admin_password = 'admin'
ambari_admin_user = 'admin'
ambari_admin_password = 'admin'
ranger_admin_user = 'admin'
ranger_admin_password = 'admin'

dps_url = sys.argv[1]
dps_auth_uri = '/auth/in'
dps_lakes_uri = '/api/lakes'
dlm_clusters_uri = '/dlm/api/clusters'
dlm_pair_uri = '/dlm/api/pair'
ambari_clusters_uri = '/api/v1/clusters'
ranger_service_uri = '/service/public/v2/api/service'
ranger_policy_uri = '/service/public/v2/api/policy'
ranger_hive_allpolicy_search_string = 'all%20-%20database,%20table,%20column'

target_cluster_name = sys.argv[2]

ranger_port = '6080'
ambari_port = '8080'

host_name = socket.getfqdn()
host_ip = socket.gethostbyname(socket.gethostname())
ranger_url = 'http://'+host_name+':'+ranger_port
headers={'content-type':'application/json'}

ambari_cluster_name = json.loads(requests.get('http://'+host_name+':'+ambari_port+ambari_clusters_uri, auth=HTTPBasicAuth(ambari_admin_user, ambari_admin_user)).content)['items'][0]['Clusters']['cluster_name']
ranger_hive_service_name = ambari_cluster_name + '_hive'

payload = '{"name":"'+ranger_hive_service_name+'","description":"","isEnabled":true,"tagService":"","configs":{"username":"hive","password":"hive","jdbc.driverClassName":"org.apache.hive.jdbc.HiveDriver","jdbc.url":"jdbc:hive2://'+host_name+':2181/;serviceDiscoveryMode=zooKeeper;zooKeeperNamespace=hiveserver2","commonNameForCertificate":""},"type":"hive"}'
ranger_hive_service = json.loads(requests.post(url=ranger_url+ranger_service_uri, auth=HTTPBasicAuth(ranger_admin_user, ranger_admin_password), data=payload, headers=headers, verify=False).content)
print 'Create Ranger Hive Service: ' + payload
ranger_hive_service_id = str(ranger_hive_service['id'])
target_policy = json.loads(requests.get(url=ranger_url+ranger_service_uri+'/'+ranger_hive_service_name+'/policy?policyName='+ranger_hive_allpolicy_search_string, auth=HTTPBasicAuth(ranger_admin_user, ranger_admin_password), data=payload, headers=headers, verify=False).content)[0]
target_policy['policyItems'][0]['users'].append('beacon')
target_policy_id = str( target_policy['id'])
payload = json.dumps(target_policy)
print 'Add Grant All on Hive Objects to Beacon user : ' + payload
print 'Result: ' + requests.put(url=ranger_url+ranger_policy_uri+'/'+target_policy_id, auth=HTTPBasicAuth(ranger_admin_user, ranger_admin_password), data=payload, headers=headers, verify=False).content

print 'Waiting for Ranger Policy to take effect...'
time.sleep(31)

token = json.loads(requests.post(url = dps_url+dps_auth_uri, data = '{"username":"'+dps_admin_user+'","password":"'+dps_admin_password+'"}',verify=False).text)['token']
cookie = {'dp_jwt':token}

requests.get(url = dps_url+'/api/knox/status', cookies = cookie, verify=False).content

payload = '{"dcName": "DC02","ambariUrl": "http://'+host_name+':'+ambari_port+'","description":" ","location": 7064,"isDatalake": true,"name": "'+ambari_cluster_name+'","state": "TO_SYNC","ambariIpAddress": "http://'+host_ip+':'+ambari_port+'","properties": {"tags": []}}'
print 'Registering Cluster with Dataplane: ' + dps_url+dps_lakes_uri
print 'Payload: ' + payload
print 'Result: ' + requests.post(url=dps_url+dps_lakes_uri, cookies=cookie, data=payload, headers=headers, verify=False).content

print 'Waiting for DPS registration to take effect...'
time.sleep(3)

if len(sys.argv) == 2:
  dlm_clusters = json.loads(requests.get(url=dps_url+dlm_clusters_uri, cookies=cookie, data=payload, headers=headers, verify=False).content)

  for dlm_cluster in dlm_clusters['clusters']:
    if dlm_cluster['name'] == ambari_cluster_name:
      dlm_source_cluster_id = str(dlm_cluster['id'])
      dlm_soruce_cluster_beacon = dlm_cluster['beaconUrl']
    elif dlm_cluster['name'] == target_cluster_cluster_name:
      dlm_dest_cluster_id = str(dlm_cluster['id'])
      dlm_dest_cluster_beacon = dlm_cluster['beaconUrl']

  payload = '[{"clusterId": '+dlm_source_cluster_id+',"beaconUrl": "'+dlm_soruce_cluster_beacon+'"},{"clusterId": '+dlm_dest_cluster_id+',"beaconUrl": "'+dlm_dest_cluster_beacon+'"}]'
  print 'Pairing Cluster with Shared Services: ' + dps_url+dlm_pair_uri
  print 'Payload: ' + payload
  print 'Result: ' + requests.post(url=dps_url+dlm_pair_uri, cookies=cookie, data=payload, headers=headers, verify=False).content
