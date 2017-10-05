
#!/usr/bin/env python
import requests, json, socket
from resource_management import *

# server configurations
config = Script.get_config()
master_configs = config['clusterHostInfo']

ambari_server_host = str(master_configs['ambari_server_host'][0])
ambari_server_port = '8080'
cluster_name = str(json.loads(requests.get('http://'+ambari_server_host+':'+ambari_server_port+'/api/v1/clusters', auth=('admin', 'admin')).content).get('items')[0].get('Clusters').get('cluster_name'))

install_dir = config['configurations']['historian-config']['historian.install.dir']
historian_repo_username = config['configurations']['historian-config']['historian.historian.repo.username']
historian_repo_password = config['configurations']['historian-config']['historian.historian.repo.password']

cronus_repo = config['configurations']['historian-config']['cronus.repo']
cronus_dir = install_dir+'/'+cronus_repo.split('/')[len(cronus_repo.split('/'))-1].replace('.git','')
cronus_repo = cronus_repo.replace('https://','https://'+historian_repo_username+':'+historian_repo_password+'@')

rhea_repo = config['configurations']['historian-config']['rhea.repo']
rhea_dir = install_dir+'/'+rhea_repo.split('/')[len(rhea_repo.split('/'))-1].replace('.git','')
rhea_repo = rhea_repo.replace('https://','https://'+historian_repo_username+':'+historian_repo_password+'@')

scythe_repo = config['configurations']['historian-config']['scythe.repo']
scythe_dir = install_dir+'/'+scythe_repo.split('/')[len(scythe_repo.split('/'))-1].replace('.git','')
scythe_repo = scythe_repo.replace('https://','https://'+historian_repo_username+':'+historian_repo_password+'@')

simulator_repo = config['configurations']['historian-config']['historian.simulator.repo']
simulator_dir = install_dir+'/'+simulator_repo.split('/')[len(simulator_repo.split('/'))-1].replace('.git','')

cronus_home_dir = config['configurations']['historian-config']['cronus.home.dir']

atlas_host_ip = socket.gethostbyname(str(json.loads(requests.get('http://'+ambari_server_host+':'+ambari_server_port+'/api/v1/clusters/'+cluster_name+'/services/ATLAS/components/ATLAS_SERVER', auth=('admin', 'admin')).content).get('host_components')[0].get('HostRoles').get('host_name')))

atlas_port = config['configurations']['application-properties']['atlas.server.http.port']

kafka_host_ip = socket.gethostbyname(str(json.loads(requests.get('http://'+ambari_server_host+':'+ambari_server_port+'/api/v1/clusters/'+cluster_name+'/services/KAFKA/components/KAFKA_BROKER', auth=('admin', 'admin')).content).get('host_components')[0].get('HostRoles').get('host_name')))

kafka_port = config['configurations']['kafka-broker']['port']

zk_host_ip = socket.gethostbyname(str(json.loads(requests.get('http://'+ambari_server_host+':'+ambari_server_port+'/api/v1/clusters/'+cluster_name+'/services/ZOOKEEPER/components/ZOOKEEPER_SERVER', auth=('admin', 'admin')).content).get('host_components')[0].get('HostRoles').get('host_name')))

zk_port = config['configurations']['zoo.cfg']['clientPort']

nifi_host_ip = socket.gethostbyname(str(json.loads(requests.get('http://'+ambari_server_host+':'+ambari_server_port+'/api/v1/clusters/'+cluster_name+'/services/NIFI/components/NIFI_MASTER', auth=('admin', 'admin')).content).get('host_components')[0].get('HostRoles').get('host_name')))

nifi_host_port = config['configurations']['nifi-ambari-config']['nifi.node.port']

api_port = config['configurations']['historian-config']['cronus.api.port']

ui_port = config['configurations']['historian-config']['rhea.ui.port']