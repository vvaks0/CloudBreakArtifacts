#!/bin/python
import sys, os, pwd, signal, time, shutil, requests, json
from subprocess import *
from resource_management import *

  def stopService(service,ambari_server_host,ambari_server_port,cluster_name):
    service_status = str(json.loads(requests.get('http://'+ambari_server_host+':'+ambari_server_port+'/api/v1/clusters/'+cluster_name+'/services/'+service, auth=('admin', 'admin')).content).get('ServiceInfo').get('state'))
    if service_status == 'STARTED':
        task_id = str(json.loads(requests.put('http://'+ambari_server_host+':'+ambari_server_port+'/api/v1/clusters/'+cluster_name+'/services/'+service, auth=('admin', 'admin'),headers={'X-Requested-By':'ambari'},data=('{"RequestInfo": {"context": "Stop '+service+'"}, "ServiceInfo": {"state": "INSTALLED"}}')).content).get('Requests').get('id'))
        loop_escape = False
        while loop_escape != True:
            task_status = str(json.loads(requests.get('http://'+ambari_server_host+':'+ambari_server_port+'/api/v1/clusters/'+cluster_name+'/requests/'+task_id, auth=('admin', 'admin')).content).get('Requests').get('request_status'))
            if task_status == 'COMPLETED':
                loop_escape = True
                time.sleep(2)
            Execute('echo Stop Service '+service+' Task Status '+task_status)
        Execute('echo Service '+service+' Stopped...')
    elif service_status == 'INSTALLED':
        Execute('echo Service '+service+' Already Stopped')
    time.sleep(2)

  def startService(service,ambari_server_host,ambari_server_port,cluster_name):
    service_status = str(json.loads(requests.get('http://'+ambari_server_host+':'+ambari_server_port+'/api/v1/clusters/'+cluster_name+'/services/'+service, auth=('admin', 'admin')).content).get('ServiceInfo').get('state'))
    if service_status == 'INSTALLED':
        task_id = str(json.loads(requests.put('http://'+ambari_server_host+':'+ambari_server_port+'/api/v1/clusters/'+cluster_name+'/services/'+service, auth=('admin', 'admin'),headers={'X-Requested-By':'ambari'},data=('{"RequestInfo": {"context": "Start '+service+'"}, "ServiceInfo": {"state": "STARTED"}}')).content).get('Requests').get('id'))
        loop_escape = False
        while loop_escape != True:
            task_status = str(json.loads(requests.get('http://'+ambari_server_host+':'+ambari_server_port+'/api/v1/clusters/'+cluster_name+'/requests/'+task_id, auth=('admin', 'admin')).content).get('Requests').get('request_status'))
            if task_status == 'COMPLETED':
                loop_escape = True
                time.sleep(2)
            Execute('echo Start '+service+' Service Task Status '+task_status)
        Execute('echo Service '+service+' Stopped...')
    elif service_status == 'STARTED':
        Execute('echo Service '+service+' Already Stopped')
    time.sleep(2)
