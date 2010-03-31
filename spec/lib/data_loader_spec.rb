require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe DataLoader do
  
  before :each do
    @loader = DataLoader.new
  end

  describe 'when getting csv' do
    it 'should convert xls to csv' do
      converted = @loader.convert(RAILS_ROOT+'/data/pl_in_progress_erdf.xls')
      converted.should == pl_csv
    end

    it 'convert an xls file to csv' do
      name = 'pl_in_progress_erdf.xls'
      file_name = RAILS_ROOT+'/data/pl/'+name
      @loader.should_receive(:convert).with(file_name).and_return pl_csv
      @loader.get_csv file_name
    end

    it 'should return contents of a csv file' do
      name = 'pl_in_progress_erdf.csv'
      file_name = RAILS_ROOT+'/data/pl/'+name
      IO.should_receive(:read).with(file_name).and_return pl_csv
      @loader.get_csv file_name
    end
    
    it 'should raise exception if not a csv or xls file' do
      name = 'pl_in_progress_erdf.doc'
      file_name = RAILS_ROOT+'/data/pl/'+name
      lambda { @loader.get_csv(file_name) }.should raise_exception      
    end
  end

  it 'should create method name without unicode' do
    name = 'Tytuł projektu'
    converted = @loader.convert_to_morph_method_name name
    converted.should == 'tytu__projektu'
  end

  it 'should load CSV' do
    fund_file = fund_files.first
    fund_file.class.name.should == 'Morph::FundFile'
    fund_file.country.should == 'POLAND'
    fund_file.parsed_data_file.should == 'pl_in_progress_erdf.csv'
  end
  
  it 'should identify fields from fund_files' do
    files = fund_files
    field_names = @loader.field_names(files.first)
    field_names.first.should == [:beneficiary, :nazwa_beneficjenta] 
    field_names.second.should == [:project_title, :tytu_projektu]
    field_names.last.should == [:program_name, :program_operacyjny]
  end

  it 'create a record for each row in fund file' do
    name = 'pl_in_progress_erdf.csv'
    fund_file = mock('fund_file', :parsed_data_file => name)
    file_name = RAILS_ROOT+'/data/pl/'+name

    @loader.should_receive(:get_csv).with(file_name).and_return pl_csv
    @loader.should_receive(:field_names).with(fund_file).and_return [
    [:beneficiary, :nazwa_beneficjenta],
    [:project_title, :tytuł_projektu],
    [:program_name, :program_operacyjny]
    ]

    records = @loader.load_fund_file fund_file
    records.size.should == 2
    record = records.first
    record.beneficiary.should == '" Enter "Ośrodek Edukacyjno - Szkoleniowy  Barbara Wolska'
    record.project_title.should == 'Szansa 50+'
    record.program_name.should == 'Program Operacyjny Kapitał Ludzki'

    record = records.second
    record.beneficiary.should == '"ARBOS" Irena Słabolepsza'
    record.project_title.should == 'Rozwój firmy ARBOS poprzez zakup rębaka do drewna'
    record.program_name.should == 'Regionalny Program Operacyjny Województwa Wielkopolskiego na lata 2007 - 2013'
  end

  def fund_files
    file_name = RAILS_ROOT+'/data/structural_funds_master_scrape_0330_vl.csv'
    IO.should_receive(:read).with(file_name).and_return csv
    fund_files = @loader.load_fund_files file_name
  end

  def pl_csv
%Q|Nazwa beneficjenta,Tytuł projektu,Program Operacyjny,Działanie,Poddziałanie,Wartość ogółem,Dofinansowanie publiczne,Rok przyznania dofinansowania,Rok wypłacenia ostatniej raty
""" Enter ""Ośrodek Edukacyjno - Szkoleniowy  Barbara Wolska",Szansa 50+,Program Operacyjny Kapitał Ludzki,7.2. Przeciwdziałanie wykluczeniu i wzmocnienie sektora ekonomii społecznej,7.2.1 Aktywizacja zawodowa i społeczna osób zagrożonych wykluczeniem społecznym,175864.0,174166.93,2008,2009
"""ARBOS"" Irena Słabolepsza",Rozwój firmy ARBOS poprzez zakup rębaka do drewna,Regionalny Program Operacyjny Województwa Wielkopolskiego na lata 2007 - 2013,Działanie 1.1. Rozwój mikroprzedsiębiorstw,Schemat I: Projekty inwestycyjne,48800.0,21000.0,2009,2009
|
  end
  
  def csv
%Q|Country,Region,Assigned to,Excel/PDF,Down-loaded,Scrape Needed,Priority,"Data
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
POLAND,All regions,,Excel,Done,No,Tier 1,,,,,ERDF,Projects in Progress,pl_in_progress_erdf.csv,Lista_beneficjentow_FE_zakonczone_030110.xls,,Nazwa beneficjenta,Tytu_ projektu,Program Operacyjny,,,,,,,,,http://www.mrr.gov.pl/aktualnosci/fundusze_europejskie_2007_2013/Documents/Lista_beneficjentow_FE_030110.rar
|
  end

end
