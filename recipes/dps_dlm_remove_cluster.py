#!/usr/bin/python

import requests, json, socket
from requests.auth import HTTPBasicAuth

shared_services_cluster_name = 'sharedservices'
dps_url = 'https://ec2-34-198-128-111.compute-1.amazonaws.com'

dps_admin_user = 'admin'
dps_admin_password = 'admin'
ambari_admin_user = 'admin'
ambari_admin_password = 'admin'
ranger_admin_user = 'admin'
ranger_admin_password = 'admin'

dps_auth_uri = '/auth/in'
dps_lakes_uri = '/api/lakes'
dlm_clusters_uri = '/dlm/api/clusters'
dlm_pair_uri = '/dlm/api/pair'
dlm_unpair_uri = '/dlm/api/unpair'
ambari_clusters_uri = '/api/v1/clusters'
ranger_service_uri = '/service/public/v2/api/service'
ranger_policy_uri = '/service/public/v2/api/policy'
ranger_hive_allpolicy_search_string = 'all%20-%20database,%20table,%20column'

ranger_port = '6080'
ambari_port = '8080'

host_name = socket.getfqdn()
host_ip = socket.gethostbyname(socket.gethostname())
ranger_url = 'http://'+host_name+':'+ranger_port

ambari_cluster_name = json.loads(requests.get('http://'+host_name+':'+ambari_port+ambari_clusters_uri, auth=HTTPBasicAuth(ambari_admin_user, ambari_admin_user)).content)['items'][0]['Clusters']['cluster_name']

token = json.loads(requests.post(url = dps_url+dps_auth_uri, data = '{"username":"'+dps_admin_user+'","password":"'+dps_admin_password+'"}',verify=False).text)['token']
cookie = {'dp_jwt':token}
headers={'content-type':'application/json'}

print "Knox Status: " + requests.get(url = dps_url+'/api/knox/status', cookies = cookie, verify=False).content

dlm_clusters = json.loads(requests.get(url=dps_url+dlm_clusters_uri, cookies=cookie, headers=headers, verify=False).content)

for dlm_cluster in dlm_clusters['clusters']:
  if dlm_cluster['name'] == ambari_cluster_name:
    dlm_source_cluster_id = str(dlm_cluster['id'])
    dlm_soruce_cluster_beacon = dlm_cluster['beaconUrl']
  elif dlm_cluster['name'] == shared_services_cluster_name:
    dlm_dest_cluster_id = str(dlm_cluster['id'])
    dlm_dest_cluster_beacon = dlm_cluster['beaconUrl']

payload = '[{"clusterId": '+dlm_source_cluster_id+',"beaconUrl": "'+dlm_soruce_cluster_beacon+'"},{"clusterId": '+dlm_dest_cluster_id+',"beaconUrl": "'+dlm_dest_cluster_beacon+'"}]'
print 'Unpairing Cluster from Shared Services: ' + payload
requests.post(url=dps_url+dlm_unpair_uri, cookies=cookie, data=payload, headers=headers, verify=False).content

dps_clusters = json.loads(requests.get(url=dps_url+dps_lakes_uri, cookies=cookie, headers=headers, verify=False).content)

for dps_cluster in dps_clusters:
  #print dps_cluster
  if dps_cluster['name'] == ambari_cluster_name:
    dps_source_cluster_id = str(dps_cluster['id'])

print 'Unregistering Cluster from Dataplane: ' + dps_url+dps_lakes_uri+'/'+dps_source_cluster_id
requests.delete(url=dps_url+dps_lakes_uri+'/'+dps_source_cluster_id, cookies=cookie, data=payload, headers=headers, verify=False).content
