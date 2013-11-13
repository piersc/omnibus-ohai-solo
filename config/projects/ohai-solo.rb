name "ohai-solo"
maintainer "ryan.walker@rackspace.com"
homepage "http://rackspace.com"

replaces        "ohai-solo"
install_path    "/opt/ohai-solo"
build_version   Omnibus::BuildVersion.new.semver
build_iteration 1

# creates required build directories
dependency "preparation"
dependency "version-manifest"
dependency "ohai-solo"

exclude "\.git*"
exclude "bundler\/git"
