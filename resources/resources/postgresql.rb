# Cookbook:: cinc-server
# Resource:: postgresql

actions :add, :remove
default_action :add

attribute :memory, kind_of: Integer, default: 1048576
attribute :datadir, kind_of: String, default: '/var/opt/cinc-project/postgresql/13/data/'
attribute :user, kind_of: String, default: 'opscode-pgsql'
attribute :group, kind_of: String, default: 'opscode-pgsql'
attribute :srmode, kind_of: String, default: 'master'
attribute :chef_active, kind_of: [TrueClass, FalseClass], default: false
attribute :netsync, kind_of: String, default: '10.0.203.0/24'
attribute :virtual_ip, kind_of: String
