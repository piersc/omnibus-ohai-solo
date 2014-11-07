name "ohai-solo"
maintainer "ryan.walker@rackspace.com"
homepage "http://rackspace.com"

replace        "ohai-solo"
install_dir    "/opt/ohai-solo"
build_version   ENV['OHAI_SOLO_VERSION'] || Omnibus::BuildVersion.new.semver

case ohai['platform']
when 'debian'
  build_iteration  "#{build_iteration}.#{ohai['platform_family']}.#{ohai['platform_version'].to_i}"
when 'ubuntu'
  build_iteration  "#{build_iteration}.#{ohai['platform']}.#{ohai['platform_version']}"
end

# creates required build directories
dependency "libgcc"
dependency "preparation"
dependency "version-manifest"
dependency "ohai"
dependency "ohai-plugins"

exclude "\.git*"
exclude "bundler\/git"

override :ruby, version: '2.1.4'
override :ohai, version: '7.2.0'
