require 'json'

include_recipe "rackspacecloud"

packages = []

r = rackspacecloud_file "package" do
  filename "dummy"
  directory node[:omnibus_ohai_solo][:rs_container]
  rackspace_username node[:omnibus_ohai_solo][:rs_username]
  rackspace_api_key node[:omnibus_ohai_solo][:rs_apikey]
  rackspace_region node[:omnibus_ohai_solo][:rs_region]
  action :nothing
end

# Find all package names and dynamically create resources
# to upload them to CloudFiles
ruby_block "find_packages" do
  block do
    packages = []
    files = Dir.glob("/var/cache/omnibus/pkg/*.json")
    files.each do |file|
      body = JSON.parse(File.read(file))
      packages << body['basename']
    end
    packages.each do |pkg|
      r.filename ::File.join("/var/cache/omnibus/pkg", pkg)
      r.run_action(:upload)
    end
  end
end