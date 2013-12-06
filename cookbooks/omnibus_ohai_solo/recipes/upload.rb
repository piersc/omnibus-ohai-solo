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
    uploads = []
    files = Dir.glob("/var/cache/omnibus/pkg/*.json")
    uploads << files
    files.each do |file|
      body = JSON.parse(File.read(file))
      uploads << body['basename']
    end
    uploads.each do |file|
      r.filename ::File.join("/var/cache/omnibus/pkg", file)
      r.run_action(:upload)
    end
    latest = files.sort_by {|file| File.mtime(file)}.last
    input = File.open(latest)
    data = input.read()
    newfile = "/var/cache/omnibus/pkg/latest.#{node[:platform]}.#{node[:platform_version]}.#{node[:kernel][:machine]}.json"
    output = File.open(newfile, 'w')
    output.write(data)
    input.close()
    output.close()
    r.filename newfile
    r.run_action(:upload) 
  end
end

