namespace :eufunds do

  task :setup_db => :environment do
    file_name = RAILS_ROOT+'/DATA/master.csv'
    loader = DataLoader.new
    loader.setup_database file_name
  end

  task :load_db => :environment do
    file_name = RAILS_ROOT+'/DATA/master.csv'
    loader = DataLoader.new
    loader.load_database file_name
  end
end
