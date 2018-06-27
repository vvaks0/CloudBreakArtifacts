#!/usr/bin/python
import requests, json, socket, time, sys, subprocess, os, shutil, glob
from requests.auth import HTTPBasicAuth
from pprint import pprint

ambari_admin_user = 'admin'
ambari_admin_password = 'admin-password1'
ranger_admin_user = 'admin'
ranger_admin_password = 'admin-password1'
ambari_clusters_uri = '/api/v1/clusters'
ambari_services_uri = '/api/v1/services'
ranger_servicedef_uri = '/service/public/v2/api/servicedef'
ranger_service_uri = '/service/public/v2/api/service'
ranger_policy_uri = '/service/public/v2/api/policy'
ranger_hive_allpolicy_search_string = 'all%20-%20database,%20table,%20column'
ranger_import_uri = '/service/plugins/policies/importPoliciesFromFile?isOverride=true&serviceType='
rm_apps_uri = '/ws/v1/cluster/apps'

home_dir = '/tmp/'
tag_policy_import_path = home_dir+'masterclass/ranger-atlas/Scripts/ranger-policies-tags.json'
hive_policy_import_path = home_dir+'masterclass/ranger-atlas/Scripts/ranger-policies.json'

zk_port = '2181'
rm_port = '8088'
ranger_port = '6080'
ambari_port = '8080'

host_name = socket.getfqdn()
host_ip = socket.gethostbyname(socket.gethostname())
rm_url = 'http://'+host_name+':'+rm_port
ranger_url = 'http://'+host_name+':'+ranger_port

#download hortonia scripts
home_dir = '/tmp/'
os.chdir(home_dir)
if not os.path.exists(home_dir+'masterclass'):
  output = subprocess.check_output(["git", "clone", "https://github.com/abajwa-hw/masterclass"])

output = subprocess.check_output(["chmod", "-R", "777", home_dir+"masterclass"])

#update zeppelin notebooks and upload to HDFS
source_dir = 'zeppelin-notebooks/'
notebooks_dir = '/usr/hdp/current/zeppelin-server/notebook/'
if not os.path.exists(home_dir+'zeppelin-notebooks'):
  output = subprocess.check_output(["git", "clone", "https://github.com/hortonworks-gallery/zeppelin-notebooks"])

files = os.listdir(source_dir)
for file in files:
  if not os.path.exists(notebooks_dir+file):
    shutil.move(source_dir+file, notebooks_dir)
  else:
    print source_dir+file +' already exists...'

subprocess.check_output(["chown", "-R", "zeppelin:hadoop", notebooks_dir])

#Configure Ranger and Import Policies
headers={'content-type':'application/json'}
ambari_cluster_name = json.loads(requests.get('http://'+host_name+':'+ambari_port+ambari_clusters_uri, auth=HTTPBasicAuth(ambari_admin_user, ambari_admin_password)).content)['items'][0]['Clusters']['cluster_name']

payload = ''
result = json.loads(requests.get(url=ranger_url+ranger_servicedef_uri+'/name/hive', auth=HTTPBasicAuth(ranger_admin_user, ranger_admin_password), data=payload, headers=headers, verify=False).content.replace('{ \\"singleValue\\":true }',' ').replace("\'"," "))
result['policyConditions'] = json.loads('[ {"itemId": 1,"name": "resources-accessed-together", "evaluator": "org.apache.ranger.plugin.conditionevaluator.RangerHiveResourcesAccessedTogetherCondition", "evaluatorOptions": {}, "label": "Resources Accessed Together?", "description": "Resources Accessed Together?" },{ "itemId": 2, "name": "not-accessed-together", "evaluator": "org.apache.ranger.plugin.conditionevaluator.RangerHiveResourcesNotAccessedTogetherCondition", "evaluatorOptions": {}, "label": "Resources Not Accessed Together?", "description": "Resources Not Accessed Together?" } ]')
result['options'] = json.loads('{"enableDenyAndExceptionsInPolicies":"true"}')
payload = json.dumps(result)
result = requests.put(url=ranger_url+ranger_servicedef_uri+'/name/hive', auth=HTTPBasicAuth(ranger_admin_user, ranger_admin_password), data=payload, headers=headers, verify=False)
print 'Enable Deny and Exceptions Policies: '
print result

payload = '{"name":"tags","description":"tags service from API","type": "tag","configs":{},"isActive":true}'
result = json.loads(requests.post(url=ranger_url+ranger_service_uri, auth=HTTPBasicAuth(ranger_admin_user, ranger_admin_password), data=payload, headers=headers, verify=False).content)
print 'Create Tag Policy Service: '
print result

services = json.loads(requests.get(url=ranger_url+ranger_service_uri, auth=HTTPBasicAuth(ranger_admin_user, ranger_admin_password), data=payload, headers=headers, verify=False).content)
for service in services:
  if service['type'] == 'hive':
    service['tagService'] = 'tags'
    payload = json.dumps(service)
    result = requests.put(url=ranger_url+ranger_service_uri+'/name/'+ambari_cluster_name+'_hive', auth=HTTPBasicAuth(ranger_admin_user, ranger_admin_password), data=payload, headers=headers, verify=False)
    print 'Associate Tag Service With Hive: '
    print result

with open(tag_policy_import_path) as tag_read:
  tag_policies = json.load(tag_read)

result = requests.post(url=ranger_url+ranger_import_uri+'tag', auth=HTTPBasicAuth(ranger_admin_user, ranger_admin_password), files={'file': ('tag-policy.json', json.dumps(tag_policies),'application/json')}, verify=False)
print 'Import Tag Policies: '
print result

with open(hive_policy_import_path) as hive_read:
  hive_policies = json.load(hive_read)

for hive_policy in hive_policies['policies']:
  hive_policy['service'] = ambari_cluster_name+'_hive'

result = requests.post(url=ranger_url+ranger_import_uri+'hive', auth=HTTPBasicAuth(ranger_admin_user, ranger_admin_password), files={'file': ('tag-policy.json', json.dumps(hive_policies),'application/json')}, verify=False)
print 'Import Hive Policies: '
print result

#Grant all to beacon user to enable DLM
target_policy = json.loads(requests.get(url=ranger_url+ranger_service_uri+'/'+ambari_cluster_name+'_hive/policy?policyName='+ranger_hive_allpolicy_search_string, auth=HTTPBasicAuth(ranger_admin_user, ranger_admin_password), data=payload, headers=headers, verify=False).content)[0]
target_policy['policyItems'][0]['users'].append('beacon')
target_policy_id = str(target_policy['id'])
payload = json.dumps(target_policy)
print 'Add Grant All on Hive Objects to Beacon user : '
print requests.put(url=ranger_url+ranger_policy_uri+'/'+target_policy_id, auth=HTTPBasicAuth(ranger_admin_user, ranger_admin_password), data=payload, headers=headers, verify=False)

# data to HDFS
os.chdir(home_dir+'masterclass/ranger-atlas/HortoniaMunichSetup')
print 'Creat Classifications... '
output = subprocess.check_output(["./typedefs_create.sh","data/classifications.json"])
print 'Create HDFS users and folders...'
output = subprocess.check_output(["su","hdfs","-c","./05-create-hdfs-user-folders.sh"])
print 'Copy data to HDFS...'
output = subprocess.check_output(["su","hdfs","-c","./06-copy-data-to-hdfs.sh"])

print 'Create Hive tables...'
beeline_url='jdbc:hive2://'+host_name+':'+zk_port+'/;serviceDiscoveryMode=zooKeeper;zooKeeperNamespace=hiveserver2'
output = subprocess.check_output(["beeline","-u",beeline_url,"-n","hive","-f","data/HiveSchema.hsql"])
#output = subprocess.check_output(["beeline","-u",beeline_url,"-n","hive","-f","data/TransSchema.hsql"])

print 'Terminate remaining Hive/Tez apps to clear queue...'
apps = json.loads(requests.get(url=rm_url+rm_apps_uri, auth=HTTPBasicAuth(ranger_admin_user, ranger_admin_password), verify=False).content)['apps']['app']
for app in apps:
  if app['applicationType'] == 'TEZ' and (app['state'] == 'RUNNING' or app['state'] == 'ACCEPTED'):
    print 'Terminating YARN application ' + app['id'] + ' of type ' + app['applicationType']
    payload = '{"state":"KILLED"}'
    result = requests.put(url=rm_url+rm_apps_uri+'/'+app['id']+'/state', auth=HTTPBasicAuth(ranger_admin_user, ranger_admin_password), data=payload, headers=headers, verify=False)
    print result

#create kafka topics and populate data - do it after kerberos to ensure Kafka Ranger plugin enabled
#output = subprocess.check_output(["./08-create-hbase-kafka.sh"])

#import Atlas entities
#print 'Import Atlas Entities: '
#output = subprocess.check_output(["./09-associate-entities-with-tags.sh"])