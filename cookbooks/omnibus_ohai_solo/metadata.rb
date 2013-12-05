name             'omnibus_ohai_solo'
maintainer       'Rackspace Hosting'
maintainer_email 'ryan.walker@rackspace.com'
license          'Apache 2.0'
description      'Builds ohai-solo packages using omnibus'
#long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.0.1'

depends "omnibus"
depends "rackspacecloud"
depends "xml"
