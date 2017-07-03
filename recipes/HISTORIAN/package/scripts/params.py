
#!/usr/bin/env python
import requests, json, socket
from resource_management import *

# server configurations
config = Script.get_config()

ambari_server_host = str(master_configs['ambari_server_host'][0])
ambari_server_port = '8080'
cluster_name = str(json.loads(requests.get('http://'+ambari_server_host+':'+ambari_server_port+'/api/v1/clusters', auth=('admin', 'admin')).content).get('items')[0].get('Clusters').get('cluster_name'))

install_dir = config['configurations']['historian-config']['historian.install_dir']
historian_repo = config['configurations']['historian-config']['historian.historian_repo']
simulator_repo = config['configurations']['historian-config']['historian.simulator_repo']

atlas_host_ip = socket.gethostbyname(str(json.loads(requests.get('http://'+ambari_server_host+':'+ambari_server_port+'/api/v1/clusters/'+cluster_name+'/services/ATLAS/components/ATLAS_SERVER', auth=('admin', 'admin')).content).get('host_components')[0].get('HostRoles').get('host_name')))

atlas_port = config['configurations']['application-properties']['atlas.server.http.port']

nifi_host_ip = socket.gethostbyname(str(json.loads(requests.get('http://'+ambari_server_host+':'+ambari_server_port+'/api/v1/clusters/'+cluster_name+'/services/NIFI/components/NIFI_MASTER', auth=('admin', 'admin')).content).get('host_components')[0].get('HostRoles').get('host_name')))

nifi_host_port = config['configurations']['nifi-ambari-config']['nifi.node.port']

api_port = config['configurations']['historian-config']['api.port']

ui_port = config['configurations']['historian-config']['ui.port']