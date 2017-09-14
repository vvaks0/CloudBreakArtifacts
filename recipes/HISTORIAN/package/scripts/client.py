import sys, os, pwd, signal, time, shutil
from subprocess import *
from resource_management import *

class DemoControlClient(Script):
  def install(self, env):
    self.configure(env)
    import params
    
    Execute('. ~/.bash_profile')
    
    if not os.path.exists(params.install_dir):  
        os.makedirs(params.install_dir)
    os.chdir(params.install_dir)
    
    if not os.path.exists(params.scythe_dir): 
        Execute('git clone ' + params.scythe_repo)
    os.chdir(params.scythe_dir)
    Execute('mvn clean package -Dmaven.test.skip=true')
    os.chdir(params.scythe_dir+'/target')
    shutil.copy('scythe-0.0.1-SNAPSHOT-jar-with-dependencies.jar', '/usr/hdp/current/spark2-client/jars')
    os.chdir(params.install_dir)
    

  def status(self, env):
    raise ClientComponentHasNoStatus()
    

  def configure(self, env):
    import params
    env.set_params(params)

if __name__ == "__main__":
  DemoControlClient().execute()
