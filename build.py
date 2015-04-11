import glob
import json
import os
import os.path
import platform
import shlex
import subprocess
import hashlib

arch = platform.machine()
dist, version, rel = platform.dist()

if 'redhat' in dist or 'centos' in dist:
    pkg_ext = '.rpm'
else:
    pkg_ext = '.deb'

pkgdir = '/var/cache/omnibus/pkg/'

release_env = os.getenv('OHAI_SOLO_RELEASE_ENV', 'latest')
ohai_solo_version = os.getenv('OHAI_SOLO_VERSION')
if not ohai_solo_version:
    os.environ['OHAI_SOLO_VERSION'] = 'master'
    ohai_solo_version = 'master'

# Run omnibus build command
print('#####################################################\n'
      'Running Omnibus build:\n'
      'Environment: %s \n'
      'Version: %s \n'
      'Pkg Ext: %s \n' % (release_env, str(ohai_solo_version), pkg_ext))

build_cmd = shlex.split("bundle exec omnibus build ohai-solo "
                        "-o=use_git_caching:false -l debug")

build = subprocess.Popen(build_cmd, stdout=subprocess.PIPE,
                         stderr=subprocess.STDOUT)
for line in iter(build.stdout.readline, ""):
    print line

metafile = glob.glob(pkgdir + '*.json')[0]
package = glob.glob(pkgdir + '*' + pkg_ext)[0]

meta = open(metafile).read()
meta = json.loads(meta)

# pack into a tar.gz
tar_name = "%s-%s-%s-%s.tar.gz" % (meta['name'], meta['version'],
                               meta['iteration'], meta['arch'])

print('#####################################################\n'
      'Creating tar.gz from package:\n'
      'Package: %s \n'
      'Metadata File: %s \n'
      'Tar: %s \n' % (package, metafile, tar_name))

pkgpath = os.path.join(pkgdir, tar_name)
if dist in ['redhat', 'centos']:
    tar_cwd = './opt'
elif dist in ['debian', 'Ubuntu']:
    tar_cwd = '/opt/'

pack = subprocess.Popen(['tar', '-czf', pkgpath, 'ohai-solo/'],
                        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                        shell=False, cwd=tar_cwd)
pack.stdout.readlines()
pack.wait()

# Update metadata variables
tar_path = os.path.join(pkgdir, tar_name)
tar_meta = meta.copy()
tar_meta['basename'] = tar_name

with open(tar_path, 'r') as read_fd:
    data = read_fd.read()
    md5 = hashlib.md5(data)
    sha1 = hashlib.sha1(data)
    sha256 = hashlib.sha256(data)
    sha512 = hashlib.sha512(data)

tar_meta['md5'] = md5.hexdigest()
tar_meta['sha1'] = sha1.hexdigest()
tar_meta['sha256'] = sha256.hexdigest()
tar_meta['sha512'] = sha512.hexdigest()

# Write package index file
latest = "%s.%s.%s.%s.json" % (release_env, meta['platform'],
                               meta['platform_version'], meta['arch'])
with open(os.path.join(pkgdir, latest), 'w') as outfile:
    json.dump(meta, outfile)

# Write tar index file
tar_latest = "%s.%s.%s.%s.tar.json" % (release_env, tar_meta['platform'],
                                   tar_meta['platform_version'],
                                   tar_meta['arch'])
with open(os.path.join(pkgdir, tar_latest), 'w') as outfile:
    json.dump(tar_meta, outfile)
