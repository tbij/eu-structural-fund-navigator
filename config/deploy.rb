require 'deprec'
  
set :application, "eu_funds"
set :domain, "eufunds.thebureauinvestigates.com"
set :repository,  "git@github.com:tbij/eu_funds.git"

# If you aren't using Subversion to manage your source code, specify
# your SCM below:
set :scm, :git
set :branch, "master"

set :ruby_vm_type,      :ree        # :ree, :mri
set :web_server_type,   :apache     # :apache, :nginx
set :app_server_type,   :passenger  # :passenger, :mongrel
set :db_server_type,    :mysql      # :mysql, :postgresql, :sqlite

set :packages_for_project, %w(libxml2 libxml2-dev libxslt1.1 libxslt1-dev) # list of packages to be installed
set :gems_for_project, %w(nokogiri) # list of gems to be installed

# Update these if you're not running everything on one host.
role :app, domain
role :web, domain
role :db,  domain, :primary => true, :no_release => true

# If you aren't deploying to /opt/apps/#{application} on the target
# servers (which is the deprec default), you can specify the actual location
# via the :deploy_to variable:
# set :deploy_to, "/opt/apps/#{application}"

namespace :deploy do

  task :restart, :roles => :app, :except => { :no_release => true } do
    top.deprec.app.restart
  end
  
  task :upload_stuff do
    data = File.read("config/database.yml")
    put data, "#{release_path}/config/database.yml", :mode => 0664
    data = File.read("config/auth.yml")
    put data, "#{release_path}/config/auth.yml", :mode => 0664
  end

  task :check_site_setup, :roles => :app do
    if is_first_run?
      site_setup
    else
      symlink_bundle
    end
  end

  def is_first_run?
    run "if [ -d #{shared_path}/.bundle ]; then echo exists ; else echo not there ; fi" do |channel, stream, message|
      if message.strip == 'not there'
        return true
      else
        return false
      end
    end
  end

  task :set_gem_bin do
    run "gem env | grep 'EXECUTABLE DIRECTORY' | sed s/.*:// | xargs echo" do |channel, stream, message|
      ENV['GEM_BIN'] = message.strip
    end unless ENV['GEM_BIN']
  end

  task :symlink_bundle, :roles => :app do
    set_gem_bin
    run "cd #{current_path}; ln -s #{shared_path}/.bundle .bundle"
    run "cd #{current_path}; #{ENV['GEM_BIN']}/bundle lock"
  end

  task :update_data, :roles => :app do
    run "if [ -d #{shared_path}/DATA ]; then cd #{shared_path}/DATA ; git pull ; else cd #{shared_path} ; git clone git@github.com:tbij/DATA.git ; fi"
    run "if [ -d #{current_path}/DATA ]; then echo data_symlinked ; else cd #{current_path} ; ln -s #{shared_path}/DATA DATA ; fi"
  end  

  task :site_setup, :roles => :app do
    puts 'entering first time only setup...'

    run "cd #{current_path}; sudo gem update --system"
    run "cd #{current_path}; sudo gem install bundler"

    set_gem_bin
    run "cd #{current_path}; #{ENV['GEM_BIN']}/bundle install"    
    run "cd #{current_path}; mv .bundle #{shared_path}/.bundle"
    symlink_bundle

    puts 'first time only setup complete!'
  end

  task :bundle_install, :roles => :app do
    set_gem_bin
    run "cd #{current_path}; #{ENV['GEM_BIN']}/bundle install"
    run "cd #{current_path}; #{ENV['GEM_BIN']}/bundle lock"
  end

  task :reindex, :roles => :app do
    run "cd #{current_path}; rake sunspot:solr:stop RAILS_ENV=production --trace"
    run "cd #{current_path}; rake sunspot:solr:start RAILS_ENV=production --trace"
    sleep 5
    run "cd #{current_path}; rake eufunds:reindex RAILS_ENV=production --trace"
  end

  task :solr_start, :roles => :app do
    run "cd #{current_path}; rake sunspot:solr:start RAILS_ENV=production --trace"
  end

  task :solr_stop, :roles => :app do
    run "cd #{current_path}; rake sunspot:solr:stop RAILS_ENV=production --trace"
  end

  task :setup_db, :roles => :app do
    run "cd #{current_path}; rake eufunds:setup_db RAILS_ENV=production --trace"
  end

  task :load_db, :roles => :app do
    run "cd #{current_path}; rake eufunds:load_db RAILS_ENV=production --trace"
  end

  task :reload, :roles => :app do
    file = ENV['file']
    country = ENV['country']
    if file
      run "cd #{current_path}; rake eufunds:reload file=#{file} RAILS_ENV=production --trace"
    end
    if country
      run "cd #{current_path}; rake eufunds:reload country=#{country} RAILS_ENV=production --trace"
    end
  end
end

after 'deploy:update_code', 'deploy:upload_stuff'
after 'deploy:symlink', 'deploy:check_site_setup', 'deploy:update_data', 'deploy:setup_db', 'deploy:load_db', 'deploy:restart'