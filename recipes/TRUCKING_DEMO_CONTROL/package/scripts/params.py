
#!/usr/bin/env python
from resource_management import *

# server configurations
config = Script.get_config()

install_dir = config['configurations']['control-config']['democontrol.install.dir']
download_url = config['configurations']['control-config']['democontrol.download.url']
sam_extentions_download_url = config['configurations']['control-config']['democontrol.sam.extensions.git.url']
