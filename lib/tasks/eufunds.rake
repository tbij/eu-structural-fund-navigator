namespace :eufunds do

  def master_file_name
    "#{RAILS_ROOT}/DATA/master.csv"
  end

  def fx_rates_file_name
    "#{RAILS_ROOT}/DATA/fx_rates.csv"
  end

  desc "resets datbase by running :setup_db, :load_db, :reindex"
  task :reset => [:setup_db, :load_db, :reindex] do
  end

  task :setup_db => :environment do
    loader = DataLoader.new
    loader.setup_database master_file_name
  end

  task :load_db => :environment do
    loader = DataLoader.new
    loader.load_database master_file_name, fx_rates_file_name
  end

  desc "reindexes fund items in solr"
  task :reindex => :environment do
    puts "reindexing fund items in solr ..."
    FundItem.reindex
    puts "reindexing finished"
  end

  task :reload => :environment do
    loader = DataLoader.new
    if country = ENV['country']
      puts "country: #{country}"
      loader.reload_country country, master_file_name, fx_rates_file_name
    end
    if file = ENV['file']
      puts "file: #{file}"
      loader.reload_file file, master_file_name, fx_rates_file_name
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
    files = f.collect{|i| "#{i.country}\t#{i.region.strip}\t#{i.parsed_data_file}" }.sort
    File.open(RAILS_ROOT + '/files_with_unknown_amount.txt', 'w') {|f| f.write files.join("\n")}
  end

  task :unknown_op => :environment do
    items = FundItem.find_by_sql('select * from fund_items where operational_program_name is null')

    ids = items.collect(&:fund_file_id).uniq
    files = FundFile.find(:all, :conditions => "id in (#{ids.join(',')})")
    text = files.collect{|i| "#{i.country}\t#{i.region.strip}\t#{i.parsed_data_file}" }.sort
    File.open(RAILS_ROOT + '/files_with_unknown_operational_program.txt', 'w') {|f| f.write text.join("\n")}

    files = files.select {|x| x.sub_program.blank?}
    text = files.collect{|i| "#{i.country}\t#{i.region.strip}\t#{i.parsed_data_file}" }.sort
    File.open(RAILS_ROOT + '/files_with_unknown_sub_program.txt', 'w') {|f| f.write text.join("\n")}
  end
end
