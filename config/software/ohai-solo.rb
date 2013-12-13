name "ohai-solo"

source :git => "git://github.com/rackerlabs/ohai-plugins"

relative_path "ohai-solo"

always_build true

build do

  command "cp -a plugins #{install_dir}"
  command "echo -e '#!\n/opt/ohai-solo/bin/ohai -d /opt/ohai-solo/plugins' > #{install_dir}/bin/ohai-solo"
  command "echo '#{build_version}' > #{build_dir}/build_version"

end
