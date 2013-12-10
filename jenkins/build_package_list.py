import json
import os
import pyrax
import pyrax.exceptions as exc

def auth(username, apikey, region):
  pyrax.set_setting("identity_type", "rackspace")
  pyrax.set_credentials(username, apikey)
  pyrax.set_setting("region", region)
  cf = pyrax.connect_to_cloudfiles(region=region) 
  return cf

def get_container(cf, container):
  cont = cf.get_container(container)
  return cont

def get_files(container, full_listing=False):
  files = container.get_objects(full_listing=full_listing)
  return files

username = os.environ['RS_USERNAME']
apikey = os.environ['RS_APIKEY']
container = os.environ['RS_CONTAINER']
region = os.environ['RS_REGION']
url_base = os.environ['RS_URL_BASE']

cf = auth(username, apikey, region)
cont = get_container(cf, container)
files = get_files(cont, full_listing=True)
manifests = []
manifest_json = {}

for file in files:
 if '.json' in file.name and 'ohai-solo' in file.name:
   data = json.loads(file.fetch())
   data['last_modified'] = file.last_modified
   manifest_json[data['basename']] = data

contents = json.dumps(manifest_json)

cf.store_object(cont, "packages.json", contents)

