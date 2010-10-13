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
    @operational_program = "Operational Programme 'Learning Environments'"
    @op_name = "Pon Istruzione FESR - Ambienti per l'apprendimento, All Priorities"
    @co_financing_rate = '50.00%'

    @fund_file = mock('fund_file',
        :parsed_data_file => @data_file,
        :country => @country,
        :level => 'national',
        :region => @region,
        :program => @program,
        :operational_program => @operational_program,
        :op_name => @op_name,
        :co_financing_rate => @co_financing_rate,
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
    @saved_fund_file = mock('saved_fund_file', :id => @saved_fund_file_id, :error => nil, :currency => 'EUR', :type => 'NationalFundFile', :country => 'POLAND', :co_financing_rate => '25.00%')
    @loader.stub!(:cmd)
  end

  describe 'when calculating amount of estimated EU funding' do
    before do
      @record = mock(Object)
      @record.stub!(:amount_allocated_private_funds).and_return 100
      @record.stub!(:amount_allocated_voluntary_funds).and_return 200
      @record.stub!(:amount_allocated_other_public_funds).and_return 300
      @co_financing_rate = 0.2
      @saved_fund_file = mock(Object, :co_financing_rate => @co_financing_rate)
    end
    def check_amount expected
      @loader.calculate_amount_estimated_eu_funding(@record, @saved_fund_file).should == expected
    end
    describe 'and amount allocated eu funds is present' do
      it 'should return amount allocated eu funds' do
        @record.stub!(:amount_allocated_eu_funds).and_return 1000
        check_amount 1000
      end
    end
    describe 'and amount allocated eu funds is not present' do
      describe 'and co-financing rate is not specified' do
        it 'should return nil' do
          @record.stub!(:co_financing_rate).and_return nil
          check_amount nil
        end
      end

      describe 'and co-financing rate is specified' do
        describe 'and "amount allocated eu funds and public funds combined" is available' do
          it 'should return the co-financing rate multiplied by the sum of the "amount allocated eu funds and public funds combined", and any private funds, voluntary funds, and other public funds' do
            @record.stub!(:amount_allocated_eu_funds_and_public_funds_combined).and_return 1000
            check_amount 1600 * @co_financing_rate
          end
        end

        describe 'and "amount allocated eu funds and public funds combined" is not available' do
          describe 'and "amount allocated public funds" is available' do
            it 'should return [“non-EU funding” [divided by]  (100% -  co-financing percentage rate)] x co-financing rate percentage' do
              @record.stub!(:amount_allocated_public_funds).and_return 1000
              check_amount ( (1600 / (1 - @co_financing_rate)) * @co_financing_rate).to_i
            end
          end

          describe 'and "amount allocated public funds" is not available' do
            describe 'and "amount paid" is not available' do
              it 'should return nil' do
                check_amount nil
              end
            end

            describe 'and "amount paid" is available' do
              before do
                @record.stub!(:amount_paid).and_return 1000
              end
              it 'should return the co-financing rate multiplied by the "amount paid"' do
                check_amount 1600 * @co_financing_rate
              end

              describe 'and "amount allocated eu funds" is 0' do
                it 'should return zero' do
                  @record.stub!(:amount_allocated_eu_funds).and_return 0
                  check_amount 0 # not 1600 * @co_financing_rate
                end
              end
            end
          end
        end
      end
    end
  end

  describe 'when loading database' do
    before :each do
      @loader.stub!(:load_normalized_beneficiaries).and_return {}
      @loader.stub!(:load_beneficiary_classification).and_return {}
    end

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
        :sub_program_information => @sub_program,
        :original_file_name => @original_file,
        :parsed_data_file => @data_file,
        :direct_link => @direct_uri,
        :last_updated=>"",
        :currency=>"EUR",
        :next_update=>"",
        :uri_to_landing_page=>"",
        :max_percent_funded_by_eu_funds=>"",
        :min_percent_funded_by_eu_funds=>"",
        :co_financing_rate=> 0.5,
        :operational_program => @operational_program,
        :op_name => @op_name
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

      @loader.should_receive(:load_a_fund_file).with(@fund_file, @saved_fund_file).and_return records

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

  it 'should load master CSV' do
    fund_file = fund_files.first
    fund_file.class.name.should == 'Morph::FundFileProxy'
    fund_file.country.should == 'POLAND'
    fund_file.region.should == 'All regions'
    fund_file.program.should == 'ERDF'
    fund_file.parsed_data_file.should == 'pl_in_progress_erdf.csv'
    fund_file.original_file_name.should == 'Lista_beneficjentow_FE_zakonczone_030110.xls'
  end

  it 'should load beneficiary_classification CSV' do
    classification = beneficiary_classification['A4E Ltd'].first
    classification.class.name.should == 'Morph::BeneficiaryClassification'
    classification.beneficiary.should == 'A4E Ltd'
    classification.category.should == 'Company'
    classification.sector_code.should == '9111 - Activities of business and employers organisations'
    classification.parent_company_or_owner.should == 'A4E'
    classification.trade_description.should == 'Welfare to Work'
    classification.ft_category.should == 'Welfare to work'
  end

  it 'should load normalized_beneficiaries CSV' do
    normalized = normalized_beneficiaries

    value = normalized['IBM Global Services Delivery Centre Polska Sp. z o.o.'].first
    value.class.name.should == 'Morph::NormalizedBeneficiary'
    value.beneficiary.should == 'IBM Global Services Delivery Centre Polska Sp. z o.o.'
    value.normalized_beneficiary.should == 'IBM'
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
    it 'should return nil for load_a_fund_file' do
      fund_file = mock(:parsed_data_file => '')
      @loader.should_not_receive(:csv_from_file)
      records = @loader.load_a_fund_file fund_file, @saved_fund_file
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
      @loader.should_receive(:load_normalized_beneficiaries).and_return {}
      @loader.stub!(:load_beneficiary_classification).and_return {}
      records = @loader.load_a_fund_file(@fund_file, @saved_fund_file)
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
      # lines[0].should == %Q|./script/generate scaffold_resource fund_file type:string error:text currency:string region:string program:string sub_program:string original_file_name:string parsed_data_file:string direct_link:string uri_to_landing_page:string max_percent_funded_by_eu_funds:string min_percent_funded_by_eu_funds:string last_updated:string next_update:string|
      lines[0].should == %Q|./script/generate scaffold_resource fund_file type:string error:text currency:string region:string program:string operational_program:string op_name:string co_financing_rate:float sub_program_information:string original_file_name:string parsed_data_file:string direct_link:string uri_to_landing_page:string max_percent_funded_by_eu_funds:string min_percent_funded_by_eu_funds:string last_updated:string next_update:string|
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
    @loader.convert_value('44.959,7').should == 44959

    @loader.convert_value('2.000 €').should == 2000
    @loader.convert_value('5.100.000 €').should == 5100000
    @loader.convert_value('8.661.908,61 €').should == 8661908
    @loader.convert_value('908,61 €').should == 908

    @loader.convert_value('2,000 €').should == 2000
    @loader.convert_value('5,100,000 €').should == 5100000
    @loader.convert_value('8,661,908.61 €').should == 8661908
    @loader.convert_value('908.61 €').should == 908
    @loader.convert_value('908.6').should == 908

    @loader.convert_value('EUR 5.100.000').should == 5100000
    @loader.convert_value('EUR 8.661.908,61').should == 8661908

    @loader.convert_value('EUR 5,100,000').should == 5100000
    @loader.convert_value('EUR 8,661,908.61').should == 8661908

    @loader.convert_value('79200.0').should == 79200
    @loader.convert_value('463706.8').should == 463706
    @loader.convert_value('5356931.54').should == 5356931

    @loader.convert_value('54 429.60').should == 54429
    @loader.convert_value('54  429.60').should == 54429

    @loader.convert_value('6027826613.92').should == 6027826613
    @loader.convert_value('56894.6666666667').should == 56894
    @loader.convert_value('602877.484426803').should == 602877
    @loader.convert_value('602877.484').should == 602877
    @loader.convert_value('877.484').should == 877484
  end

  describe 'when asked to normalize beneficiaries' do
    it 'should add normalized name' do
      normalized_beneficiaries
      record = mock('record', :beneficiary => 'IBM Global Services Delivery Centre Polska Sp. z o.o.')
      records = [record]
      record.should_receive(:normalized_beneficiary=).with('IBM')
      @loader.normalize_beneficiaries(records).should == records
    end
  end

  describe 'when asked to classify beneficiary' do
    describe 'and record has a normalized_beneficiary field' do
      it 'should add classification fields to record' do
        beneficiary_classification
        record = mock('record', :normalized_beneficiary => 'A4E Ltd')
        records = [record]
        record.should_receive(:classification_category=).with('Company')
        record.should_receive(:sector_code=).with('9111 - Activities of business and employers organisations')
        record.should_receive(:parent_company_or_owner=).with('A4E')
        record.should_receive(:trade_description=).with('Welfare to Work')
        record.should_receive(:ft_category=).with('Welfare to work')

        @loader.classify_beneficiaries(records).should == records
      end
    end
    describe 'and record does not have a normalized_beneficiary field' do
      it 'should add classification fields to record' do
        beneficiary_classification
        record = mock('record', :beneficiary => 'A4E Ltd')
        records = [record]
        record.should_receive(:classification_category=).with('Company')
        record.should_receive(:sector_code=).with('9111 - Activities of business and employers organisations')
        record.should_receive(:parent_company_or_owner=).with('A4E')
        record.should_receive(:trade_description=).with('Welfare to Work')
        record.should_receive(:ft_category=).with('Welfare to work')

        @loader.classify_beneficiaries(records).should == records
      end
    end
  end

  def beneficiary_classification
    beneficiary_classification = "#{RAILS_ROOT}/DATA/beneficiary_classification.csv"
    IO.should_receive(:read).with(beneficiary_classification).and_return beneficiary_classification_csv
    @loader.load_beneficiary_classification(beneficiary_classification)
  end

  def normalized_beneficiaries
    normalized_beneficiaries = "#{RAILS_ROOT}/DATA/normalized_beneficiaries.csv"
    IO.should_receive(:read).with(normalized_beneficiaries).and_return normalized_beneficiaries_csv
    @loader.load_normalized_beneficiaries(normalized_beneficiaries)
  end

  def fund_files
    file_name = "#{RAILS_ROOT}/DATA/master.csv"
    IO.should_receive(:read).with(file_name).and_return master_csv
    fund_files = @loader.load_fund_files file_name
  end

  def pl_csv
%Q|Nazwa beneficjenta,Tytuł projektu,Program Operacyjny,Działanie,Poddziałanie,Wartość ogółem,Dofinansowanie publiczne,Rok przyznania dofinansowania,Rok wypłacenia ostatniej raty
""" Enter ""Ośrodek Edukacyjno - Szkoleniowy  Barbara Wolska",Szansa 50+,Program Operacyjny Kapitał Ludzki,7.2. Przeciwdziałanie wykluczeniu i wzmocnienie sektora ekonomii społecznej,7.2.1 Aktywizacja zawodowa i społeczna osób zagrożonych wykluczeniem społecznym,175864.0,174166.93,2008,2009
"""ARBOS"" Irena Słabolepsza",Rozwój firmy ARBOS poprzez zakup rębaka do drewna,Regionalny Program Operacyjny Województwa Wielkopolskiego na lata 2007 - 2013,Działanie 1.1. Rozwój mikroprzedsiębiorstw,Schemat I: Projekty inwestycyjne,48800.0,21000.0,2009,2009
|
  end

  def beneficiary_classification_csv
%Q|beneficiary,category,sector_code,parent_company_or_owner,trade_description,ft_category
A4E Ltd,Company,9111 - Activities of business and employers organisations,A4E,Welfare to Work,Welfare to work|
  end

  def normalized_beneficiaries_csv
%Q|beneficiary,normalized_beneficiary
IBM Global Services Delivery Centre Polska Sp. z o.o.,IBM|
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
