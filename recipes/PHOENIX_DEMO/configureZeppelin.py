#!/usr/bin/python

import sys, json, requests

zeppelinHost=sys.argv[1]
zeppelinPort=sys.argv[2]
zeppelinUserName='admin'
zeppelinPassword='admin'
notebookSourceUrl='https://raw.githubusercontent.com/vakshorton/CloudBreakArtifacts/master/recipes/PHOENIX_DEMO/notebook/PhoenixETE.json'

#Get Authenticate and store Token/Cookie
jar=requests.post('http://'+zeppelinHost+':'+zeppelinPort+'/api/login','userName='+zeppelinUserName+'&password='+zeppelinPassword).cookies
#Get all interpreters
interpreters=json.loads(requests.get('http://'+zeppelinHost+':'+zeppelinPort+'/api/interpreter/setting',cookies=jar).text)['body']

sparkInterpreterId = ''
sparkInterpreterPayload = ''
#Loop over interpreters to get Spark interpreter definition
for interpreter in interpreters:
  if interpreter['name']=='spark':
    sparkInterpreterId = interpreter['id']
    sparkInterpreterPayload = interpreter
    break

#Add configurations to Spark interpreter
sparkInterpreterPayload['properties'].update({'spark.executor.cores':2})
sparkInterpreterPayload['properties'].update({'spark.executor.memory':'4096m'})
sparkInterpreterPayload['properties'].update({'spark.executor.instances':50})

sparkInterpreterPayloadJSON = json.dumps(sparkInterpreterPayload)

#Update Spark interpreter
requests.put('http://'+zeppelinHost+':'+zeppelinPort+'/api/interpreter/setting/'+sparkInterpreterId,cookies=jar,data=sparkInterpreterPayloadJSON)

#Get Notebook Payload
notebook=json.dumps(json.loads(requests.get(notebookSourceUrl).text))
#Import Notebook
requests.post('http://'+zeppelinHost+':'+zeppelinPort+'/api/notebook/import',cookies=jar,data=notebook)