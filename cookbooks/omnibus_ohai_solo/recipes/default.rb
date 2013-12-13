
git "/opt/omnibus-ohai-solo" do
  repository node[:omnibus_ohai_solo][:repo]
  reference node[:omnibus_ohai_solo][:ref]
  action :sync
end

git "/opt/ohai-plugins" do
  repository node[:ohai_plugins][:repo]
  reference node[:ohai_plugins][:ref]
  action :sync
end

script "BUILD ALL THE THINGS" do
  interpreter 'bash'
  if node[:omnibus_ohai_solo][:append_timestamp] == "true"
    environment("OMNIBUS_APPEND_TIMESTAMP" => "true")
  else
    environment("OMNIBUS_APPEND_TIMESTAMP" => "false")
  end
  cwd "/opt/omnibus-ohai-solo"
  code <<-OMNIBUS_BUILD
    export PATH=/usr/local/bin:$PATH
    cd /opt/omnibus-ohai-solo
    bundle install --binstubs
    bin/omnibus build project ohai-solo
  OMNIBUS_BUILD
end
