import sys, os, pwd, signal, time, shutil, platform
from subprocess import *
from resource_management import *

class DemoControlClient(Script):
  def install(self, env):
    self.configure(env)
    import params
    
    Execute('. ~/.bash_profile')
    Execute('yum install -y git')
    Execute('yum install -y wget')
    
    Execute('wget http://repos.fedorapeople.org/repos/dchen/apache-maven/epel-apache-maven.repo -O 	/etc/yum.repos.d/epel-apache-maven.repo')
    
    sysos = str(platform.platform())
    if 'amzn' in sysos:
        Execute('sed -i s/\$releasever/6/g /etc/yum.repos.d/epel-apache-maven.repo')
    
    Execute('yum install -y apache-maven')
    
    if 'amzn' in sysos:
        Execute('alternatives --install /usr/bin/java java /usr/lib/jvm/jre-1.8.0-openjdk.x86_64/bin/java 20000')
        Execute('alternatives --install /usr/bin/javac javac /usr/lib/jvm/jre-1.8.0-openjdk.x86_64/bin/javac 20000')
        Execute('alternatives --auto java')
        Execute('alternatives --auto javac')
        Execute('ln -s /usr/lib/jvm/java-1.8.0 /usr/lib/jvm/java')
    
    if not os.path.exists(params.install_dir):  
        os.makedirs(params.install_dir)
    os.chdir(params.install_dir)
    
    if not os.path.exists(params.scythe_dir): 
        Execute('git clone ' + params.scythe_repo)
    os.chdir(params.scythe_dir)
    Execute('git pull origin master')
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
