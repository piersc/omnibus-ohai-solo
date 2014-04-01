name "ohai-solo"
maintainer "ryan.walker@rackspace.com"
homepage "http://rackspace.com"

replaces        "ohai-solo"
install_path    "/opt/ohai-solo"
build_version   ENV['OHAI_SOLO_VERSION'] || Omnibus::BuildVersion.new.semver

case platform
when 'debian'
  build_iteration  "#{build_iteration}.#{platform_family}.#{platform_version.to_i}"
when 'ubuntu'
  build_iteration  "#{build_iteration}.#{platform}.#{platform_version}"
end

# creates required build directories
dependency "preparation"
dependency "version-manifest"
dependency "ohai"
dependency "ohai-plugins"

exclude "\.git*"
exclude "bundler\/git"
