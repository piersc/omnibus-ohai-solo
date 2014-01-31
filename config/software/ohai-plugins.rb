name "ohai-plugins"

source :git => "git://github.com/rackerlabs/ohai-plugins"
version "ohai7"

relative_path "ohai-plugins"

always_build true

dependency "cacerts"

build do

  command "cp -a plugins #{install_dir}"
  command "echo '#!\n/opt/ohai-solo/bin/ohai -d /opt/ohai-solo/plugins' > #{install_dir}/bin/ohai-solo"
  command "chmod +x #{install_dir}/bin/ohai-solo"
  command "echo '#{build_version}' > #{build_dir}/build_version"

end
