namespace :eufunds do

  task :reset => :environment do
    file_name = RAILS_ROOT+'/DATA/master.csv'
    loader = DataLoader.new
    loader.load_database file_name
  end

end
