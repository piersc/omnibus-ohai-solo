import json
import md5
import os
import pyrax
import pyrax.exceptions as exc

import pdb


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


def get_checksum(data):
    checksum = md5.new(data).hexdigest()
    return checksum


def upload(container, contents, checksum):
    print "Uploading packages.json..."
    print "packages.json checksum: %s" % checksum
    obj = cf.store_object(container, "packages.json", contents)

    if obj:
        stored_contents = obj.get()
        obj_checksum = get_checksum(stored_contents)
        print "Upload complete!"
        if checksum == obj_checksum:
            print "Checksums verified: %s" % obj_checksum
        else:
            print "ERROR: Object checksum %s does not match contents \
                  checksum %s" % (obj_checksum, checksum)
            raise
    else:
        print "ERROR: Upload failed!"
        raise

username = os.environ['RS_USERNAME']
apikey = os.environ['RS_APIKEY']
container_name = os.environ['RS_CONTAINER']
region = os.environ['RS_REGION']

cf = auth(username, apikey, region)
container = get_container(cf, container_name)
files = get_files(container, full_listing=True)
manifests = []
manifest_json = {}
existing_file = None

for file in files:
    if '.json' in file.name and 'ohai-solo' in file.name:
        data = json.loads(file.fetch())
        data['last_modified'] = file.last_modified
        manifest_json[data['basename']] = data
    if file.name == 'packages.json':
        existing_file = file.get()

contents = json.dumps(manifest_json)
checksum = get_checksum(contents)

if existing_file:
    existing_checksum = get_checksum(existing_file)
    if existing_checksum == checksum:
        print "File Checksums Match - Skipping Upload"
    else:
        upload(container, contents, checksum)
else:
        upload(container, contents, checksum)
