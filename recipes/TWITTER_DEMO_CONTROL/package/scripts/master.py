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
    Execute(params.install_dir + '/CloudBreakArtifacts/recipes/twitter-install.sh ' + params.install_dir)

  #def start(self, env):
  #  self.configure(env)
  #  import params
 
  #def stop(self, env):
  #  self.configure(env)
  #  import params
    
  #def status(self, env):
  #  import params
  #  env.set_params(params)
    
  def configure(self, env):
    import params
    env.set_params(params)

if __name__ == "__main__":
  DemoControl().execute()
