import sys, os, pwd, signal, time, shutil
from subprocess import *
from resource_management import *

class DemoControl(Script):
  def install(self, env):
    self.configure(env)
    import params
  
    if not os.path.exists(params.install_dir):  
        os.makedirs(params.install_dir)
    os.chdir(params.install_dir)
    Execute('git clone ' + params.simulator_repo)
    os.chdir(params.install_dir+'/DataSimulators/DeviceSimulator')
    Execute('mvn clean package')
    os.chdir(params.install_dir+'/DataSimulators/DeviceSimulator/target')
    shutil.copy('DeviceSimulator-0.0.1-SNAPSHOT-jar-with-dependencies.jar', params.install_dir)
    os.chdir(params.install_dir)
    Execute('git clone ' + params.historian_repo)
    os.chdir(params.install_dir+'/historian')
    Execute('mvn package docker:build')
    Execute(params.install_dir+'/CloudBreakArtifacts/recipes/historian-service-install.sh')

  def start(self, env):
    self.configure(env)
    import params
    Execute('echo Start UI')
    Execute('docker run -p -d '+parmas.ui_port+':8080 -e ATLAS_HOST='+parmas.atlas_host+' -e ATLAS_PORT='+parmas.atlas_port+' -e API_HOST='+parmas.nifi_host_ip+' -e API_PORT='+parmas.api_port+' -t hortonworks/historian')
    #Execute('nohup java -jar target/historian-0.0.1.jar --server.port=8095 > historian.log &')
    Execute('echo Start Simulation')
    Execute('nohup java -jar '+params.install_dir+'/DeviceSimulator-0.0.1-SNAPSHOT-jar-with-dependencies.jar Historian 1000 Simulation '+params.nifi_host_ip+' > '+params.install_dir+'/historian_sim.log 2>&1 & echo $! > /var/run/historian_sim.pid')
    
  def stop(self, env):
    self.configure(env)
    import params
    Execute('echo Stop UI')
    Execute('docker rm $(docker stop $(docker ps -a -q --filter ancestor=hortonworks/historian --format="{{.ID}}"))')
    Execute('echo Stop Simulation')
    Execute (format('kill -9 `cat /var/run/historian_sim.pid` >/dev/null 2>&1')) 
    Execute ('rm -f /var/run/historian_sim.pid')
    
  def status(self, env):
    import params
    env.set_params(params)
    check_process_status('/var/run/historian_sim.pid')
    
  def configure(self, env):
    import params
    env.set_params(params)

if __name__ == "__main__":
  DemoControl().execute()
