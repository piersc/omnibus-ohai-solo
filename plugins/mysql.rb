provides "mysql"

require_plugin 'linux::lsb'

mysql Mash.new

mysql_bin = %x(which mysql).strip
mysql[:bin] = mysql_bin

mysqladmin = %x(which mysqladmin).strip
status = %x(#{mysqladmin} status).strip
status = Hash[status.scan(/(\w+): (\w+)/).map { |(k, v)| [k.downcase.to_sym, v.to_i] }]
mysql[:status] = status
