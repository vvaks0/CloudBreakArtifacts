#!/usr/bin/python

import requests, json, socket, time, sys
from requests.auth import HTTPBasicAuth

if len(sys.argv) < 2:
  print 'Need at least 1 argument [dps_host_name] and at most 2 arguments [target_cluster_name]'
  exit(1)

dps_url = 'https://' + sys.argv[1]

dps_admin_user = 'admin'
dps_admin_password = 'admin'
ambari_admin_user = 'admin'
ambari_admin_password = 'admin-password'
ranger_admin_user = 'admin'
ranger_admin_password = 'admin-password'

dps_auth_uri = '/auth/in'
dps_lakes_uri = '/api/lakes'
dlm_clusters_uri = '/dlm/api/clusters'
dlm_pairs_uri = '/dlm/api/pairs'
dlm_unpair_uri = '/dlm/api/unpair'
dlm_policies_uri = '/dlm/api/policies?numResults=200'
ambari_clusters_uri = '/api/v1/clusters'
ranger_service_uri = '/service/public/v2/api/service'
ranger_policy_uri = '/service/public/v2/api/policy'
ranger_hive_allpolicy_search_string = 'all%20-%20database,%20table,%20column'

ranger_port = '6080'
ambari_port = '8080'

host_name = socket.getfqdn()
host_ip = socket.gethostbyname(socket.gethostname())
ranger_url = 'http://'+host_name+':'+ranger_port
headers={'content-type':'application/json'}

ambari_cluster_name = json.loads(requests.get('http://'+host_name+':'+ambari_port+ambari_clusters_uri, auth=HTTPBasicAuth(ambari_admin_user, ambari_admin_password)).content)['items'][0]['Clusters']['cluster_name']

#token = json.loads(requests.post(url = dps_url+dps_auth_uri, data = '{"username":"'+dps_admin_user+'","password":"'+dps_admin_password+'"}', headers=headers, verify=False).text)['token']
token = requests.post(url = dps_url+dps_auth_uri, data = '{"username":"'+dps_admin_user+'","password":"'+dps_admin_password+'"}', headers=headers, verify=False).cookies.pop('dp_jwt')
cookie = {'dp_jwt':token}

print "Knox Status: " + requests.get(url = dps_url+'/api/knox/status', cookies = cookie, verify=False).content

dlm_clusters = json.loads(requests.get(url=dps_url+dlm_clusters_uri, cookies=cookie, headers=headers, verify=False).content)

clusters = {}
for dlm_cluster in dlm_clusters['clusters']:
  clusters[dlm_cluster['name']+'_id'] = dlm_cluster['id']
  clusters[dlm_cluster['name']+'_dc'] = dlm_cluster['dataCenter']

currClusterName = clusters[ambari_cluster_name+'_dc']+'$'+ambari_cluster_name

dlm_policies = json.loads(requests.get(url=dps_url+dlm_policies_uri, cookies=cookie, headers=headers, verify=False).content)

target_policies = []
for dlm_policy in dlm_policies['policies']:
  if (dlm_policy['sourceCluster'] == currClusterName) or (dlm_policy['targetCluster'] == currClusterName):
    target_policies.append('/'+str(clusters[dlm_policy['targetCluster'].split('$')[1]+'_id'])+'/policy/'+dlm_policy['name'])
    requests.delete(url=dps_url+dlm_clusters_uri+target_policies[0], cookies=cookie, headers=headers, verify=False).content

dlm_pairs = json.loads(requests.get(url=dps_url+dlm_pairs_uri, cookies=cookie, headers=headers, verify=False).content)
for dlm_pair in dlm_pairs['pairedClusters']:
    if (dlm_pair[0]['name'] == ambari_cluster_name) or (dlm_pair[1]['name'] == ambari_cluster_name):
      dlm_dest_cluster_id = str(dlm_pair[0]['id'])
      dlm_dest_cluster_name = dlm_pair[0]['name']
      dlm_dest_cluster_beacon = dlm_pair[0]['beaconUrl']
      dlm_dest_cluster_dc = dlm_pair[0]['dataCenter']
      dlm_source_cluster_id = str(dlm_pair[1]['id'])
      dlm_source_cluster_name = dlm_pair[1]['name']
      dlm_source_cluster_beacon = dlm_pair[1]['beaconUrl']
      dlm_source_cluster_dc = dlm_pair[1]['dataCenter']
      payload = '[{"clusterId": '+dlm_source_cluster_id+',"beaconUrl": "'+dlm_source_cluster_beacon+'"},{"clusterId": '+dlm_dest_cluster_id+',"beaconUrl": "'+dlm_dest_cluster_beacon+'"}]'
      print 'Unpairing Cluster : ' + payload
      requests.post(url=dps_url+dlm_unpair_uri, cookies=cookie, data=payload, headers=headers, verify=False).content

dps_clusters = json.loads(requests.get(url=dps_url+dps_lakes_uri, cookies=cookie, headers=headers, verify=False).content)

for dps_cluster in dps_clusters:
  #print dps_cluster
  if dps_cluster['name'] == ambari_cluster_name:
    dps_source_cluster_id = str(dps_cluster['id'])

print 'Unregistering Cluster from DPS: ' + dps_url+dps_lakes_uri+'/'+dps_source_cluster_id
print 'Result: ' + requests.delete(url=dps_url+dps_lakes_uri+'/'+dps_source_cluster_id, cookies=cookie, headers=headers, verify=False).content
