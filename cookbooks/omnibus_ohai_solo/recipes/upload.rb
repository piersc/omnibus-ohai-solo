require 'json'
require 'time'

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
    files.each do |file|
      uploads << File.basename(file)
      body = JSON.parse(File.read(file))
      uploads << body['basename']
    end
    uploads.each do |file|
      r.filename ::File.join("/var/cache/omnibus/pkg", file)
      r.run_action(:upload)
    end

    # Only use major version for RHEL/Cent and Debian.
    platform = nil
    if platform?("redhat", "centos", "debian")
      version = node[:platform_version].to_i
      # Make json manifest name match package name for RHEL/Cent.
      platform = "el" unless platform?("debian")
    else
      version = node[:platform_version]
    end

    if node[:omnibus_ohai_solo][:release_environment] == "prod"
      release = "latest"
    else
       release = node[:omnibus_ohai_solo][:release_environment]
    end

    latest = files.sort_by {|file| File.mtime(file)}.last
    data = JSON.parse(IO.read(latest))
    last_modified = Time.now().getgm.strftime("%Y-%m-%dT%H:%M:%S")
    data['last_modified'] = last_modified
    newfile = "/var/cache/omnibus/pkg/#{release}.#{platform || node[:platform]}.#{version}.#{node[:kernel][:machine]}.json"
    output = File.open(newfile, 'w')
    output.write(JSON.dump(data))
    output.close()
    r.filename newfile
    r.run_action(:upload) 
  end
end

