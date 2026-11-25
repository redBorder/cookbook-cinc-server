default['cinc-server']['services']['chef'] = true
default['cinc-server']['services']['nginx'] = true
default['cinc-server']['services']['postgresql'] = true
default['cinc-server']['chef_middleware'] = %w(bookshelf oc_bifrost oc_id opscode-erchef redis_lb opensearch)
default['cinc-server']['services_list'] = %w(postgresql nginx bookshelf oc_bifrost oc_id
                                             opscode-erchef redis_lb opensearch)
default['cinc-server']['install_dir'] = '/opt/cinc-project'
default['cinc-server']['config_dir'] = '/etc/cinc-project'
default['cinc-server']['services_dir'] = '/opt/cinc-project/service'
default['cinc-server']['user'] = 'cinc'

# flags
default['cinc-server']['installed'] = false
default['cinc-server']['datastore_configured'] = false
default['cinc-server']['registered'] = false
