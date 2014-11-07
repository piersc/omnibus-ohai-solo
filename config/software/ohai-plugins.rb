name "ohai-plugins"

source :git => "git://github.com/rackerlabs/ohai-plugins"
default_version "master"

relative_path "ohai-plugins"

#always_build true

dependency "libgcc"
dependency "cacerts"

build do

  command "cp -a plugins #{install_dir}"
  command "echo '#!\n/opt/ohai-solo/bin/ohai -d /opt/ohai-solo/plugins' > #{install_dir}/bin/ohai-solo"
  command "chmod +x #{install_dir}/bin/ohai-solo"
  command "echo '#{ENV['OHAI_SOLO_VERSION']}' > #{build_dir}/build_version"

end
