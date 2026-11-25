# Cookbook:: cinc-server
# Provider:: config

action :add do
  begin
    chef_active = new_resource.chef_active
    postgresql = new_resource.postgresql
    postgresql_memory = new_resource.postgresql_memory
    postgresql_vip = new_resource.postgresql_vip
    netsync = new_resource.netsync
    chef_config_path = new_resource.chef_config_path
    s3_secrets = new_resource.s3_secrets
    install_dir = node['cinc-server']['install_dir']
    config_dir = node['cinc-server']['config_dir']
    cinc_user = node['cinc-server']['user']

    # Keep cinc-server-ctl working on nodes where RVM exports its Ruby environment.
    # chef-server-ctl is kept as an alias because redborder-manager scripts still call it.
    %w(cinc-server-ctl chef-server-ctl).each do |ctl|
      cookbook_file "/usr/local/bin/#{ctl}" do
        source 'cinc-server-ctl-wrapper.sh'
        cookbook 'cinc-server'
        owner 'root'
        group 'root'
        mode '0755'
      end
    end

    link '/root/chef' do
      to '/var/chef'
      action ::File.directory?('/var/chef') ? :create : :delete
    end

    # Chef Server is still installed: the switch to Cinc is done by rb_migrate_to_cinc.sh, not here
    if ::File.directory?('/opt/opscode') && !::File.directory?(install_dir)
      Chef::Log.warn('Chef Server (/opt/opscode) is still installed. Run rb_migrate_to_cinc.sh to migrate to Cinc.')
    # Only executed if it's a custom node with cinc-server
    elsif !::File.directory?(install_dir) && !node['cinc-server']['installed']

      Chef::Log.info('Installing cinc-server services')
      # install cinc-server package
      dnf_package 'redborder-cinc-server' do
        action :upgrade
      end

      directory config_dir do
        owner 'root'
        group 'root'
        mode '0755'
      end

      execute 'Set 4443 as cinc-server proxy SSL default port' do
        command "echo \"nginx['ssl_port'] = 4443\" >> #{config_dir}/cinc-server.rb"
      end

      execute 'Set 4080 as cinc-server proxy non SSL default port' do
        command "echo \"nginx['non_ssl_port'] = 4080\" >> #{config_dir}/cinc-server.rb"
      end

      # cinc-server reconfigure (Cinc has no license to accept)
      execute 'Configuring cinc-server' do
        command '/usr/local/bin/cinc-server-ctl reconfigure &>> /root/.install-cinc-server.log'
      end

      file "#{config_dir}/private-cinc-secrets.json" do
        owner cinc_user
        group cinc_user
        mode '0600'
        action :touch
        only_if { ::File.exist?("#{config_dir}/private-cinc-secrets.json") }
      end

      # stop cinc-server services
      execute 'Stopping default cinc-server services' do
        command '/usr/local/bin/cinc-server-ctl graceful-kill'
      end

      # cinc-server installation finished
      node.default['cinc-server']['installed'] = true

      # cinc-server datastore configuration
      unless node['cinc-server']['datastore_configured']
        # Load Database configuration
        begin
          db_opscode_chef = data_bag_item('passwords', 'db_opscode_chef')
        rescue
          db_opscode_chef = {}
        end

        unless db_opscode_chef.empty?
          Chef::Log.info('Configuring cinc-server database')
          db_host = db_opscode_chef['hostname']
          db_port = db_opscode_chef['port']
          db_name = db_opscode_chef['database']
          db_user = db_opscode_chef['username']
          db_pass = db_opscode_chef['pass']
          ocid_pass = db_opscode_chef['ocid_pass']
          ocbifrost_pass = db_opscode_chef['ocbifrost_pass']

          bash 'update_chef_db' do
            ignore_failure true
            code <<-EOH
                # Change erchef database configuration
                sed -i 's|{db_host,.*|{db_host, \"#{db_host}\"},|' #{chef_config_path}/opscode-erchef/sys.config
                sed -i 's|{db_port,.*|{db_port, #{db_port}},|' #{chef_config_path}/opscode-erchef/sys.config
                sed -i 's|{db_name,.*|{db_name, \"#{db_name}\"},|' #{chef_config_path}/opscode-erchef/sys.config
                sed -i 's|{db_user,.*|{db_user, \"#{db_user}\"},|' #{chef_config_path}/opscode-erchef/sys.config
                sed -i 's|{db_pass,.*|{db_pass, \"#{db_pass}\"},|' #{chef_config_path}/opscode-erchef/sys.config
                #Change oc_id configuration
                sed -i 's|{host:.*|{host: #{db_host}|' #{chef_config_path}/oc_id/config/database.yml
                sed -i 's|{port:.*|{port: #{db_port}|' #{chef_config_path}/oc_id/config/database.yml
                sed -i 's|{password:.*|{password: #{ocid_pass}|' #{chef_config_path}/oc_id/config/database.yml
                #Change oc_bifrost configuration
                sed -i 's|{db_host,.*|{db_host, \"#{db_host}\"},|' #{chef_config_path}/oc_bifrost/sys.config
                sed -i 's|{db_port,.*|{db_port, #{db_port}},|' #{chef_config_path}/oc_bifrost/sys.config
                sed -i 's|{db_pass,.*|{db_pass, \"#{ocbifrost_pass}\"},|' #{chef_config_path}/oc_bifrost/sys.config
              EOH
            action :run
          end
        end

        unless s3_secrets.empty?
          Chef::Log.info('Configuring cinc-server cookbook storage')
          s3_access_key_id = s3_secrets['s3_access_key_id']
          s3_secret_key_id = s3_secrets['s3_secret_key_id']
          s3_url           = s3_secrets['s3_url']
          s3_bucket        = s3_secrets['s3_bucket']

          bash 'update_chef_s3' do
            ignore_failure true
            code <<-EOH
               sed -i 's|{s3_access_key_id,.*|{s3_access_key_id, \"#{s3_access_key_id}\"},|' #{chef_config_path}/opscode-erchef/sys.config
               sed -i 's|{s3_secret_key_id,.*|{s3_secret_key_id, \"#{s3_secret_key_id}\"},|' #{chef_config_path}/opscode-erchef/sys.config
               sed -i 's|{s3_url,.*|{s3_url, \"#{s3_url}\"},|' #{chef_config_path}/opscode-erchef/sys.config
               sed -i 's|{s3_external_url,.*|{s3_external_url, \"#{s3_url}\"},|' #{chef_config_path}/opscode-erchef/sys.config
               sed -i 's|{s3_platform_bucket_name,.*|{s3_platform_bucket_name, \"#{s3_bucket}\"},|' #{chef_config_path}/opscode-erchef/sys.config
               EOH
            action :run
          end
        end

        node.default['cinc-server']['datastore_configured'] = true
      end

      # Replace cinc-server runit scripts with the redborder systemd units
      execute 'Stopping default cinc-server services' do
        command '/usr/local/bin/cinc-server-ctl stop'
      end

      # Delete symbolic links of cinc-server runit scripts
      node['cinc-server']['services_list'].each do |ln_file|
        link "#{node['cinc-server']['services_dir']}/#{ln_file}" do
          action :delete
        end
      end

      if chef_active
        node['cinc-server']['chef_middleware'].each do |srv|
          service srv.include?('opscode') ? srv : "opscode-#{srv}" do
            action :start
          end
        end

        restart_list = "ls #{install_dir}/sv/ | sed 's/opscode-//g'"
        restart_list += ' | grep -v postgresql' unless postgresql
        execute 'Restart cinc-server services' do
          command "for i in `#{restart_list}`; do systemctl restart opscode-$i; done"
        end
      end
    else
      node.default['cinc-server']['installed'] = true
      node.default['cinc-server']['datastore_configured'] = true
    end

    # Change default permissions of crt file needed by webui (644)
    file "/root/.chef/trusted_certs/#{node['hostname']}.crt" do
      owner 'root'
      group 'root'
      mode '0644'
      action :touch
      only_if { ::File.exist?("/root/.chef/trusted_certs/#{node['hostname']}.crt") }
    end

    if postgresql
      # call to postgresql resource
      cinc_server_postgresql 'Postgresql configuration' do
        memory postgresql_memory
        chef_active false
        srmode 'master'
        netsync netsync
        virtual_ip postgresql_vip
        action :add
      end
    end

    Chef::Log.info('cinc-server cookbook has been processed')
  rescue => e
    Chef::Log.error(e.message)
  end
end

action :remove do
  begin
    Chef::Log.info('cinc-server cookbook has been processed')
  rescue => e
    Chef::Log.error(e.message)
  end
end

action :register do
  begin
    ipaddress = new_resource.ipaddress
    consul_servers = system('serf members -tag consul=ready | grep consul=ready &> /dev/null')
    unless node['cinc-server']['registered'] && consul_servers
      query = {}
      query['ID'] = "erchef-#{node['hostname']}"
      query['Name'] = 'erchef'
      query['Address'] = ipaddress
      query['Port'] = 4443
      json_query = Chef::JSONCompat.to_json(query)

      execute 'Register service in consul' do
        command "curl -X PUT http://localhost:8500/v1/agent/service/register -d '#{json_query}' &>/dev/null"
        action :nothing
      end.run_action(:run)

      node.normal['cinc-server']['registered'] = true
      Chef::Log.info('cinc-server services have been registered to consul')
    end
  rescue => e
    Chef::Log.error(e.message)
  end
end

action :deregister do
  begin
    consul_servers = system('serf members -tag consul=ready | grep consul=ready &> /dev/null')
    if node['cinc-server']['registered'] && consul_servers
      execute 'Deregister service in consul' do
        command "curl -X PUT http://localhost:8500/v1/agent/service/deregister/erchef-#{node['hostname']} &>/dev/null"
        action :nothing
      end.run_action(:run)

      node.normal['cinc-server']['registered'] = false
      Chef::Log.info('cinc-server services have been deregistered from consul')
    end
  rescue => e
    Chef::Log.error(e.message)
  end
end
