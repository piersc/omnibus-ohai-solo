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

# Run omnibus build command
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

# unpack package
if 'redhat' in dist or 'centos' in dist:
    unpack = subprocess.Popen("rpm2cpio %s|cpio -i" % package,
    		              stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              shell=True)
if 'debian' in dist or 'Ubuntu' in dist:
    unpack = subprocess.Popen(['dpkg', '--unpack', package],
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              shell=False)
unpack.wait()
   
# pack into a tar.gz
name = "%s-%s-%s-%s%s-%s.tar.gz" % (meta['name'], meta['version'],
                                    meta['iteration'], meta['platform'],
                                    meta['platform_version'], meta['arch'])
pkgpath = os.path.join(pkgdir, name)
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
meta['basename'] = name
with open(pkgpath, 'r') as read_fd:
    md5 = hashlib.md5()
    sha1 = hashlib.sha1()
    sha256 = hashlib.sha256()
    sha512 = hashlib.sha512()
    while True:
        data = read_fd.read(2048)
        if not data:
            break
        md5.update(data)
        sha1.update(data)
        sha256.update(data)
        sha512.update(data)

    meta['md5'] = md5.hexdigest()
    meta['sha1'] = sha1.hexdigest()
    meta['sha256'] = sha256.hexdigest()
    meta['sha512'] = sha512.hexdigest()

# Write index file
latest = "%s.%s.%s.%s.json" % (release_env, meta['platform'], meta['platform_version'], meta['arch']) 
with open(os.path.join(pkgdir, latest), 'w') as outfile:
    json.dump(meta, outfile)
