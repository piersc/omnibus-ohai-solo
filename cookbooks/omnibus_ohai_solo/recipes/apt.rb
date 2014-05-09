# Force apt-get update at compile time because of a bunch of silliness.
e = execute 'apt-get-update' do
  command 'apt-get update'
  ignore_failure true
  only_if { apt_installed? }
  action :nothing
end
e.run_action(:run)
