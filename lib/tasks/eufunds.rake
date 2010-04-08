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
  
  task :excel_to_csv => :environment do
    file_name = RAILS_ROOT+'/'+ARGV[1]
    loader = DataLoader.new
    puts "converting: #{file_name}"
    csv = loader.convert file_name
    csv_file = file_name.sub(/xls$/,'csv')
    puts "saving: #{csv_file}"
    File.open(csv_file,'w') {|f| f.write csv}
  end
end
