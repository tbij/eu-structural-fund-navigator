require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe DataLoader do
  
  before :each do
    @loader = DataLoader.new
    @loader.stub!(:load_fx_rates)
    @loader.stub!(:get_fx_rate).and_return 1
    @data_file = 'pl_in_progress_erdf.csv'

    @country = 'POLAND'
    @region = 'All regions'
    @program = 'ERDF'
    @sub_program = 'Media'
    @original_file = 'original_file_name'
    @direct_uri = 'http://example.com/'

    @fund_file = mock('fund_file',
        :parsed_data_file => @data_file,
        :country_or_countries => @country,
        :level => 'national',
        :region => @region,
        :program => @program,
        :sub_program_information => @sub_program,
        :original_file_name => @original_file,
        :direct_link_to_pdf => @direct_uri,
        :currency => 'EUR',
        :uri_to_landing_page => '',
        :agency_that_oversees_funding => '',
        :percent_funded_by_eu_funds_minimum => '',
        :percent_funded_by_eu_funds_maximum => '',
        :last_updated => '',
        :next_update => ''
        )
    @saved_fund_file_id = 'example_id'
    @saved_fund_file = mock('saved_fund_file', :id => @saved_fund_file_id, :error => nil, :currency => 'EUR', :type => 'NationalFundFile', :country => 'POLAND')
    @loader.stub!(:cmd)
  end
  
  describe 'when loading database' do
    it 'should pick files with data' do
      @loader.with_data([@fund_file]).should == [@fund_file]      
    end
    it 'should ignore files without data' do
      fund_file = mock('fund_file', :parsed_data_file => nil)
      @loader.with_data([fund_file]).should be_empty      
    end
    it 'should save fund file' do
      fund_file_model = mock('FundFileClass')
      country_model = mock('CountryClass')
      fund_file_country_model = mock('FundFileCountryClass')
      
      @loader.should_receive(:fund_file_model).with(@fund_file).and_return fund_file_model
      @loader.should_receive(:country_model).and_return country_model
      @loader.should_receive(:fund_file_country_model).and_return fund_file_country_model
      country_obj = mock('country_obj', :id => 'country_id')
      fund_file_obj = mock('fund_file_obj', :id => 'fund_file_id')
      country_fund_file_obj = mock('country_fund_file_obj')

      attributes = {
        :region => @region,
        :program => @program,
        :sub_program => @sub_program,
        :original_file_name => @original_file,
        :parsed_data_file => @data_file,
        :direct_link => @direct_uri,
        :last_updated=>"", 
        :currency=>"EUR",
        :next_update=>"", 
        :agency=>"",
        :uri_to_landing_page=>"", 
        :max_percent_funded_by_eu_funds=>"", 
        :min_percent_funded_by_eu_funds=>""        
      }

      fund_file_country_attributes = {
        :country_id => country_obj.id,
        :fund_file_id => fund_file_obj.id
      }      
      country_model.should_receive(:find_or_create_by_name).with(@country).and_return country_obj

      fund_file_model.should_receive(:create).with(attributes).and_return(fund_file_obj)
      
      fund_file_country_model.should_receive(:create).with(fund_file_country_attributes).and_return(country_fund_file_obj)
      
      @loader.save_fund_file(@fund_file).should == fund_file_obj
    end

    it 'should populate database' do
      file_name = RAILS_ROOT+'/spec/fixtures/data/master.csv'
      first_fund = mock('first_fund', :parsed_data_file => 'parsed_data_file')
      fund_files = [ first_fund ]
      @loader.should_receive(:migrate_database)
      @loader.should_receive(:load_fund_files).with(file_name).and_return fund_files      
      @loader.should_receive(:with_data).with(fund_files).and_return fund_files
      @loader.should_receive(:populate_database).with(fund_files, fund_files)
      @loader.load_database file_name, 'x'
    end

    it 'should run scaffold generate and reset db' do
      destroy_migration_cmds = "zero"
      country_migration_cmds = "zero"
      file_migration_cmds = "first\nsecond"
      migration_cmds = "third\nfourth"
      fields = mock('fields')
      @loader.should_receive(:destroy_migration).and_return destroy_migration_cmds
      @loader.should_receive(:country_migration).and_return country_migration_cmds
      @loader.should_receive(:fund_file_migration).and_return file_migration_cmds
      @loader.should_receive(:fund_item_migration).with(fields).and_return migration_cmds
      @loader.should_receive(:cmd).with('zero')
      @loader.should_receive(:cmd).with('zero')
      @loader.should_receive(:cmd).with('first')
      @loader.should_receive(:cmd).with('second')
      @loader.should_receive(:cmd).with('third')
      @loader.should_receive(:cmd).with('fourth')
      @loader.should_receive(:add_index)
      @loader.reset_database fields
    end

    it 'should migrate db' do      
      @loader.should_receive(:cmd).with(%Q|rake db:migrate RAILS_ENV=test --trace|)
      @loader.should_receive(:cmd).with(%Q|rake db:reset RAILS_ENV=test --trace|)
      @loader.should_receive(:cmd).with(%Q|rm spec/controllers/*_controller_spec.rb|)

      @loader.should_receive(:add_associations)
      @loader.migrate_database
    end
    
    it 'should load fund file records in db' do
      fund_file = mock('fund_file')
      fund_file2 = mock('fund_file2')
      fund_files = [@fund_file, fund_file, fund_file2]
      fund_files_with_data = [@fund_file]

      record = mock('record')
      record2 = mock('record2')
      record3 = mock('record3')
      records = [record, record2, record3]

      saved_fund_file = mock('saved_fund_file')
      saved_fund_file2 = mock('saved_fund_file')
      @loader.should_receive(:save_fund_file).with(@fund_file).and_return @saved_fund_file
      @loader.should_receive(:save_fund_file).with(fund_file).and_return saved_fund_file
      @loader.should_receive(:save_fund_file).with(fund_file2).and_return saved_fund_file2
      
      @loader.should_receive(:load_fund_file).with(@fund_file, @saved_fund_file).and_return records
      
      @loader.should_receive(:save_record).with(record, nil, @saved_fund_file)
      @loader.should_receive(:save_record).with(record2, nil, @saved_fund_file)
      @loader.should_receive(:save_record).with(record3, nil, @saved_fund_file)
      @loader.populate_database(fund_files, fund_files_with_data)
    end
    
    it 'should save record' do
      morph_attributes = {:x => 'y', :beneficiary => 'Acme', :currency => 'currency'}
      record = mock('record', :morph_attributes => morph_attributes, :beneficiary => 'Acme')
      model = mock('FundItemClass')
      @loader.should_receive(:record_model).and_return model
      model.should_receive(:create).with(morph_attributes).and_return mock('item') 
      @loader.save_record record
    end
    
    it 'should prevent saving record if beneficiary and project title missing' do
      record = mock('record')
      lambda { @loader.save_record record }.should raise_exception
    end
  end

  describe 'when getting csv' do
    it 'should convert xls to csv' do
      converted = @loader.convert_excel_to_csv(RAILS_ROOT+'/spec/fixtures/data/pl/pl_in_progress_erdf.xls')
      converted.should == pl_csv
    end

    it 'convert an xls file to csv' do
      name = 'pl_in_progress_erdf.xls'
      file_name = RAILS_ROOT+'/DATA/pl/'+name
      File.should_receive(:exist?).with(file_name).and_return true
      @loader.should_receive(:convert_excel_to_csv).with(file_name).and_return pl_csv
      @loader.csv_from_file file_name
    end

    it 'should return contents of a csv file' do
      name = 'pl_in_progress_erdf.csv'
      file_name = RAILS_ROOT+'/DATA/pl/'+name
      File.should_receive(:exist?).with(file_name).and_return true
      IO.should_receive(:read).with(file_name).and_return pl_csv
      @loader.csv_from_file file_name
    end
    
    it 'should raise exception if not a csv or xls file' do
      name = 'pl_in_progress_erdf.doc'
      file_name = RAILS_ROOT+'/DATA/pl/'+name
      File.should_receive(:exist?).with(file_name).and_return true
      lambda { @loader.csv_from_file(file_name) }.should raise_exception      
    end
  end

  it 'should load CSV' do
    fund_file = fund_files.first
    fund_file.class.name.should == 'Morph::FundFileProxy'
    fund_file.country_or_countries.should == 'POLAND'
    fund_file.region.should == 'All regions'
    fund_file.program.should == 'ERDF'
    fund_file.parsed_data_file.should == 'pl_in_progress_erdf.csv'
    fund_file.original_file_name.should == 'Lista_beneficjentow_FE_zakonczone_030110.xls'
  end
  
  it 'should identify fields from fund_files' do
    files = fund_files
    field_names = @loader.field_names(files.first)
    field_names.first.should == [:currency, "EUR"] 
    field_names.second.should == [:beneficiary, "Nazwa beneficjenta"] 
    field_names.third.should == [:project_title, "Tytuł projektu"]
    field_names.last.should == [:program_name, "Program Operacyjny"]
  end

  describe 'when parsed data file not present' do
    it 'should return nil for load_fund_file' do  
      fund_file = mock(:parsed_data_file => '')
      @loader.should_not_receive(:csv_from_file)
      records = @loader.load_fund_file fund_file, @saved_fund_file
      # records.should be_nil
    end
  end

  describe 'when creating records' do
    before do
      file_name = RAILS_ROOT+'/DATA/pl/'+@data_file
      @loader.stub!(:csv_from_file).with(file_name).and_return pl_csv
      @loader.stub!(:field_names).with(@fund_file).and_return [
        [:beneficiary, "Nazwa beneficjenta"],
        [:project_title, "Tytuł projektu"],
        [:program_name, "Program Operacyjny"],
        [:amount_unknown, "Dofinansowanie publiczne"]
      ]
    end

    it 'should create a record for each row in fund file' do
      records = @loader.load_fund_file(@fund_file, @saved_fund_file)
      records.size.should == 2
      record = records.first
      record.fund_file_id.should == @saved_fund_file_id
      record.beneficiary.should == '" Enter "Ośrodek Edukacyjno - Szkoleniowy  Barbara Wolska'
      record.project_title.should == 'Szansa 50+'
      record.program_name.should == 'Program Operacyjny Kapitał Ludzki'
  
      record = records.second
      record.fund_file_id.should == @saved_fund_file_id
      record.beneficiary.should == '"ARBOS" Irena Słabolepsza'
      record.project_title.should == 'Rozwój firmy ARBOS poprzez zakup rębaka do drewna'
      record.program_name.should == 'Regionalny Program Operacyjny Województwa Wielkopolskiego na lata 2007 - 2013'
    end
    
    it 'should destroy old migrations' do
      lines = @loader.destroy_migration.split("\n")
      lines[0].should == %Q|./script/destroy scaffold_resource fund_file_country|      
      lines[1].should == %Q|./script/destroy scaffold_resource country|
      lines[2].should == %Q|./script/destroy scaffold_resource fund_item|
      lines[3].should == %Q|./script/destroy scaffold_resource fund_file|
    end

    it 'should create country migration' do
      lines = @loader.country_migration.split("\n")
      lines[0].should == %Q|./script/generate scaffold_resource country name:string|
    end

    it 'should create fund_file_migration' do
      lines = @loader.fund_file_migration.split("\n")
      lines[0].should == %Q|./script/generate scaffold_resource fund_file type:string error:text currency:string region:string agency:string program:string sub_program:string original_file_name:string parsed_data_file:string direct_link:string uri_to_landing_page:string max_percent_funded_by_eu_funds:string min_percent_funded_by_eu_funds:string last_updated:string next_update:string|
      lines[1].should == %Q|./script/generate scaffold_resource fund_file_country country_id:integer fund_file_id:integer|
    end

    it 'should create fund_item_migration' do
      lines = @loader.fund_item_migration([:fund_file_id, :beneficiary, :project_title, :program_name]).split("\n")

      lines[0].should == %Q|./script/generate scaffold_resource fund_item fund_file_id:integer beneficiary:string project_title:string program_name:string|
    end
  end

  it 'should convert values' do
    @loader.convert_value('').should == nil
    @loader.convert_value(nil).should == nil

    @loader.convert_value('471,408.00 �').should == 471408

    @loader.convert_value('€70.000,00').should == 70000 
    @loader.convert_value('-').should == nil
    @loader.convert_value(' €44.959,74').should == 44959
    
    @loader.convert_value('2.000 €').should == 2000
    @loader.convert_value('5.100.000 €').should == 5100000
    @loader.convert_value('8.661.908,61 €').should == 8661908
    @loader.convert_value('908,61 €').should == 908

    @loader.convert_value('2,000 €').should == 2000
    @loader.convert_value('5,100,000 €').should == 5100000
    @loader.convert_value('8,661,908.61 €').should == 8661908
    @loader.convert_value('908.61 €').should == 908

    @loader.convert_value('EUR 5.100.000').should == 5100000
    @loader.convert_value('EUR 8.661.908,61').should == 8661908

    @loader.convert_value('EUR 5,100,000').should == 5100000
    @loader.convert_value('EUR 8,661,908.61').should == 8661908
    
    @loader.convert_value('79200.0').should == 79200
    @loader.convert_value('463706.8').should == 463706
    @loader.convert_value('5356931.54').should == 5356931
    
    @loader.convert_value('54 429.60').should == 54429
    @loader.convert_value('54  429.60').should == 54429
  end

  def fund_files
    file_name = RAILS_ROOT+'/DATA/master.csv'
    IO.should_receive(:read).with(file_name).and_return master_csv
    fund_files = @loader.load_fund_files file_name
  end

  def pl_csv
%Q|Nazwa beneficjenta,Tytuł projektu,Program Operacyjny,Działanie,Poddziałanie,Wartość ogółem,Dofinansowanie publiczne,Rok przyznania dofinansowania,Rok wypłacenia ostatniej raty
""" Enter ""Ośrodek Edukacyjno - Szkoleniowy  Barbara Wolska",Szansa 50+,Program Operacyjny Kapitał Ludzki,7.2. Przeciwdziałanie wykluczeniu i wzmocnienie sektora ekonomii społecznej,7.2.1 Aktywizacja zawodowa i społeczna osób zagrożonych wykluczeniem społecznym,175864.0,174166.93,2008,2009
"""ARBOS"" Irena Słabolepsza",Rozwój firmy ARBOS poprzez zakup rębaka do drewna,Regionalny Program Operacyjny Województwa Wielkopolskiego na lata 2007 - 2013,Działanie 1.1. Rozwój mikroprzedsiębiorstw,Schemat I: Projekty inwestycyjne,48800.0,21000.0,2009,2009
|
  end
  
  def master_csv
%Q|Country/Countries,Level,Region,Assigned to,Excel/PDF,Down-loaded,Scrape Needed,Priority,"Data
available
for
2007","Data
available
for
2008","Data
available
for
2009","Data
available
for2010",Program,"Sub-program
information",Parsed data file,Original file name,Currency Field,Beneficiary Field,Project Title Field,Program Name Field,Amount Allocated Field (EU Funds),Amount Allocated (All funds EU/Nation/Region),Amount Paid Field,Description Field,Year Field,Date Field,Start Year Field,,Direct link to PDF,"Direct link to
Excel","Direct Link to 
HTML",Direct link to Doc,,Last Updated,Next update ,Explanatory Notes,Waiting for response,Contact,Uri to landing page,Contact
POLAND,national,All regions,,Excel,Done,No,Tier 1,,,,,ERDF,Projects in Progress,pl_in_progress_erdf.csv,Lista_beneficjentow_FE_zakonczone_030110.xls,EUR,Nazwa beneficjenta,Tytuł projektu,Program Operacyjny,,,,,,,,,http://www.mrr.gov.pl/aktualnosci/fundusze_europejskie_2007_2013/Documents/Lista_beneficjentow_FE_030110.rar
|
  end

end
