provides "apache2"

require_plugin 'linux::lsb'

apache2 Mash.new

case lsb[:id].downcase
when "ubuntu", "debian"
  apache2ctl_bin = %x(which apache2ctl).strip
  apache2_bin = %x(which apache2).strip
when "rhel", "centos"
  apache2ctl_bin = %x(which httpd).strip
  apache2_bin = %x(which httpd).strip
end

apache2[:bin] = apache2_bin

apache2[:clients] = (%x(ps -eo euser,ruser,suser,fuser,f,cmd |grep #{apache2_bin}|grep -v grep|wc -l).to_i - 1)

popen4("#{apache2_bin} -V") do |pid, stdin, stdout, stderr|
  stdin.close
  stdout.each do |line|
    case line
    when /-D HTTPD_ROOT=["']?(.+?)["']?$/
      apache2[:config_path] = $1
    when /Server version:\s(.+?)?$/
      apache2[:version] = $1
    when /Server MPM:\s(.+?)?$/
      apache2[:mpm] = $1.strip.downcase
    when /-D SERVER_CONFIG_FILE=["']?(.+?)["']?$/
      apache2[:config_file] = $1.strip
    end
  end
end

apache2[:config_file] = apache2[:config_path] + "/" + apache2[:config_file]

case apache2[:mpm]
when "prefork"
  max_clients = %x(grep -A8 -i mpm_prefork_module #{apache2[:config_file]}|grep MaxClients).strip
  apache2[:max_clients] = (max_clients.split)[1].to_i
end

popen4("#{apache2_bin} -S") do |pid, stdin, stdout, stderr|
  stdin.close
  stderr.each do |line|
    case line
    when /WARNING: Require MaxClients > 0, setting to\s(.+?)?$/
      apache2[:max_clients] = $1.to_i
    when /Syntax OK/
      apache2[:syntax_ok] = true
    when /Syntax error\s(.+?)?$/
      apache2[:syntax_ok] = false
      errors = $1.split(": ")
      errors[0] = "Syntax error " + errors[0]
      apache2[:syntax_errors] = errors
    end
  end
end
