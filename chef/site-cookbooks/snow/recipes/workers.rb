include_recipe "snow::common"
include_recipe "apt"
include_recipe "nodejs"
include_recipe "postgresql::client"
include_recipe "cron"

package 'git' do
end

include_recipe 'deploy_wrapper'
bag = Chef::EncryptedDataBagItem.load("snow", 'main')
env_bag = bag[node.chef_environment]

ssh_known_hosts_entry 'github.com'

deploy_wrapper 'workers' do
    ssh_wrapper_dir '/home/ubuntu/workers-ssh-wrapper'
    ssh_key_dir '/home/ubuntu/.ssh'
    ssh_key_data bag["github_private_key"]
    owner "ubuntu"
    group "ubuntu"
    sloppy true
end

# Deployment config
deploy_revision node[:snow][:workers][:app_directory] do
    user "ubuntu"
    group "ubuntu"
    repo env_bag["repository"]["main"]["url"]
    branch env_bag["repository"]["main"]["branch"]
    ssh_wrapper "/home/ubuntu/workers-ssh-wrapper/workers_deploy_wrapper.sh"
    action :deploy
    branch node[:snow][:branch]
    before_symlink do
      bash "npm install" do
        user "root"
        group "root"
        cwd "#{release_path}/workers"
        code %{
          npm install
        }
      end
    end
    keep_releases 2
    symlinks({
         "config/workers.json" => "workers/config/#{node.chef_environment}.json"
    })
    symlink_before_migrate({})
    create_dirs_before_symlink(['workers', 'workers/config'])
    purge_before_symlink([])
end

# Application config
directory "#{node[:snow][:workers][:app_directory]}/shared" do
  owner "ubuntu"
  group "ubuntu"
end

directory "#{node[:snow][:workers][:app_directory]}/shared/config" do
  owner "ubuntu"
  group "ubuntu"
end

pgm_ip = NetworkUtils.get_private_ipv4_for_node(search(:node, 'role:pgm').first)
pgs_ip = NetworkUtils.get_private_ipv4_for_node(search(:node, 'role:pgs').first)

template "#{node[:snow][:workers][:app_directory]}/shared/config/workers.json" do
    source 'workers/config.json.erb'
    variables({
        :pgm_ip => pgm_ip || '127.0.0.1',
        :pgs_ip => pgs_ip || '127.0.0.1',
        :website_url => env_bag['api']['website_url'],
        :ripple => env_bag['ripple'],
        :armory => env_bag['armory'],
        :env_bag => env_bag
    })
end

#monit_monitrc "snow-workers" do
#end

template "/usr/bin/liability-proof.sh" do
    source "liability-proof.sh.erb"
    owner "root"
    group "root"
    mode 0755
end

cron_d "liability-proof" do
  minute  0
  command '/usr/bin/liability-proof.sh'
  user "postgres"
end

