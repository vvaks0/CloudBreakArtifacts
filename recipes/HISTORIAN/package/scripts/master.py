import sys, os, pwd, signal, time, shutil
from subprocess import *
from resource_management import *

class DemoControl(Script):
  def install(self, env):
    self.configure(env)
    import params
    
    Execute('. ~/.bash_profile')
    
    if not os.path.exists(params.install_dir):  
        os.makedirs(params.install_dir)
    os.chdir(params.install_dir)
    
    if not os.path.exists(params.simulator_dir): 
        Execute('git clone ' + params.simulator_repo)
    os.chdir(params.simulator_dir+'/DeviceSimulator')
    Execute('mvn clean package')
    os.chdir(params.simulator_dir+'/DeviceSimulator/target')
    shutil.copy('DeviceSimulator-0.0.1-SNAPSHOT-jar-with-dependencies.jar', params.install_dir)
    os.chdir(params.install_dir)
    
    if not os.path.exists(params.scythe_dir): 
        Execute('git clone ' + params.scythe_repo)
    os.chdir(params.scythe_dir)
    Execute('mvn clean package')
    os.chdir(params.scythe_dir+'/target')
    shutil.copy('scythe-0.0.1-SNAPSHOT-jar-with-dependencies.jar', '/usr/hdp/current/spark2-client/jars')
    os.chdir(params.install_dir)
    
    if not os.path.exists(params.rhea_dir): 
        Execute('git clone ' + params.rhea_repo)
    os.chdir(params.rhea_dir)
    Execute('mvn package docker:build')
    os.chdir(params.install_dir)
    
    if not os.path.exists(params.cronus_dir): 
        Execute('git clone ' + params.cronus_repo)
    
    shutil.copytree(params.cronus_dir+'/data', params.cronus_data_dir, False, None)
    shutil.copytree(params.cronus_dir+'/urls', params.cronus_urls_dir, False, None)
    shutil.copytree(params.cronus_dir+'/scripts', params.cronus_scripts_dir, False, None)
    
    nifi_env_file = open('/usr/hdf/current/nifi/conf/env.properties','w+')
    nifi_env_file.write("data.dir=" + params.cronus_data_dir)
    nifi_env_file.write("urls.dir=" + params.cronus_urls_dir)
    nifi_env_file.write("scripts.dir=" + params.cronus_scripts_dir)
    
    os.chdir(params.install_dir)
    Execute(params.install_dir+'/CloudBreakArtifacts/recipes/historian-service-install.sh '+params.cronus_dir)

  def start(self, env):
    self.configure(env)
    import params
    Execute('echo Start Rhea UI')
    Execute('docker run -d -p '+params.ui_port+':8080 -e ATLAS_HOST='+params.atlas_host_ip+' -e ATLAS_PORT='+params.atlas_port+' -e API_HOST='+params.nifi_host_ip+' -e API_PORT='+params.api_port+' -t hortonworks/rhea')
    #Execute('nohup java -jar target/historian-0.0.1.jar --server.port=8095 > historian.log &')
    Execute('echo Start Data Simulation')
    Execute('nohup java -jar '+params.install_dir+'/DeviceSimulator-0.0.1-SNAPSHOT-jar-with-dependencies.jar Historian 1000 Simulation '+params.nifi_host_ip+' > '+params.install_dir+'/historian_sim.log 2>&1 & echo $! > /var/run/historian_sim.pid')
    
  def stop(self, env):
    self.configure(env)
    import params
    Execute('echo Stop UI')
    Execute('docker rm $(docker stop $(docker ps -a -q --filter ancestor=hortonworks/rhea --format="{{.ID}}"))')
    Execute('echo Stop Simulation')
    Execute (format('kill -9 `cat /var/run/historian_sim.pid` >/dev/null 2>&1')) 
    Execute ('rm -f /var/run/historian_sim.pid')
    
  def status(self, env):
    check_process_status('/var/run/historian_sim.pid')
    
  def configure(self, env):
    import params
    env.set_params(params)

if __name__ == "__main__":
  DemoControl().execute()
