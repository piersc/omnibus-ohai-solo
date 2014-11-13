import glob
import json
import os
import platform
import shlex
import subprocess
import sys

arch = platform.machine()
dist, version, rel = platform.dist()

if 'redhat' in dist:
    pkg_ext = '.rpm'
else:
    pkg_ext = '.deb'

pkgdir = '/var/cache/omnibus/pkg/'

release_env = os.getenv('OHAI_SOLO_RELEASE_ENV', 'latest')
ohai_solo_version = os.getenv('OHAI_SOLO_VERSION')
if not ohai_solo_version:
    os.environ['OHAI_SOLO_VERSION'] = 'master'

# Run omnibus build command
build_cmd = shlex.split("bin/omnibus build ohai-solo "
                        "-o=use_git_caching:false -l debug")

build = subprocess.Popen(build_cmd, stdout=subprocess.PIPE,
                         stderr=subprocess.STDOUT)
for line in iter(build.stdout.readline, ""):
    print line

metafile = glob.glob(pkgdir + '*.json')[0]
package = glob.glob(pkgdir + '*' + pkg_ext)[0]

meta = open(metafile).read()
meta = json.loads(meta)

# Fix naming convention for Cent/RHEL
if 'redhat' in dist:
    name = ("%s-%s-%s.%s%s.%s%s" % (meta['name'], meta['version'],
                                    str(meta['iteration']), meta['platform'],
                                    meta['platform_version'], meta['arch'],
                                    pkg_ext))

    new_meta = ("%s-%s-%s.%s%s.%s%s%s" % (meta['name'], meta['version'],
                                          str(meta['iteration']),
                                          meta['platform'],
                                          meta['platform_version'],
                                          meta['arch'], pkg_ext,
                                          '.metadata.json'))

    os.rename(os.path.join(pkgdir, meta['basename']), os.path.join(pkgdir,
                                                                   name))
    os.rename(os.path.join(metafile), os.path.join(pkgdir, new_meta))
    meta['basename'] = name


# Write index file
latest = "%s.%s.%s.%s.json" % (release_env, meta['platform'],
                               meta['platform_version'], meta['arch'])

with open(os.path.join(pkgdir, latest), 'w') as outfile:
    json.dump(meta, outfile)
