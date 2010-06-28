namespace :eufunds do

  def master_file_name
    "#{RAILS_ROOT}/DATA/master.csv"
  end

  task :setup_db => :environment do
    loader = DataLoader.new
    loader.setup_database master_file_name
  end

  task :load_db => :environment do
    loader = DataLoader.new
    loader.load_database master_file_name
  end
  
  task :reload => :environment do
    loader = DataLoader.new
    if country = ENV['country']
      puts "country: #{country}"
      loader.reload_country country, master_file_name
    end
    if file = ENV['file']
      puts "file: #{file}"
      loader.reload_file file, master_file_name
    end
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
  
  task :unknown => :environment do
    a = FundItem.find_by_sql('select * from fund_items where amount_unknown_source is not null')
    x = a.collect(&:fund_file_id).uniq
    f = FundFile.find(x)
    files = f.collect{|i| i.country + ', ' + i.region.strip + ': ' + i.parsed_data_file}.sort
    File.open(RAILS_ROOT + '/files_with_unknown_amount.txt', 'w') {|f| f.write files.join("\n")}
  end
end
