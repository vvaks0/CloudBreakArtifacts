import sys
import os
import shutil
from subprocess import *
from resource_management import *

class Plugin(Script):
  def install(self, env):
    print 'Install the config client';
    src_dir = ('/var/lib/ambari-agent/cache/stacks/HDP/2.5/services/RANGER_HIVE_PLUGIN/package/configuration')
    dest_dir = ('/usr/hdp/current/hive-server2/conf/conf.server')
    src_files = os.listdir(src_dir)
    for file_name in src_files:
        full_file_name = os.path.join(src_dir, file_name)
        if (os.path.isfile(full_file_name)):
                shutil.copy(full_file_name, dest_dir)

  def configure(self, env):
    print 'Configure the config client';

  def status(self, env):
        raise ClientComponentHasNoStatus()

if __name__ == "__main__":
  Plugin().execute()
