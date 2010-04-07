require 'roo'
require 'morph'

class FundRecord
  include Morph
end

class DataLoader

  def load_database file_name
    fund_files = load_fund_files file_name
    fund_files.each { |fund_file| puts fund_file.parsed_data_file ; load_fund_file fund_file, nil }
    reset_database fund_files.first
    populate_database fund_files
  end
  
  def cmd line
    puts line
    puts `#{line}`
  end

  def add_index
    Dir.chdir(RAILS_ROOT)
    fund_items_migration = Dir.glob("#{RAILS_ROOT}/db/migrate/*_create_fund_items.rb").first
    text = IO.read(fund_items_migration)
    File.open(fund_items_migration, 'w') do |f|
      f.write text.sub(%Q|t.timestamps
    end|, 
    %Q|t.timestamps
    end
    add_index :fund_items, :fund_file_id|)
    end
  end

  def reset_database fund_file
    records = load_fund_file(fund_file, nil)
    fund_file_migration.each_line {|line| cmd line.strip }
    fund_item_migration(records.first).each_line {|line| cmd line.strip }

    add_index
    %Q|rake db:migrate
    rake db:reset
    rm spec/controllers/fund_items_controller_spec.rb
    rm spec/controllers/fund_files_controller_spec.rb
    rake db:test:clone_structure|.each_line {|line| cmd line.strip }

    File.open("#{RAILS_ROOT}/app/models/fund_file.rb", 'w') do |f|
      f.write %Q|class FundFile < ActiveRecord::Base
  has_many :fund_items
end|
    end
  end
  
  def populate_database fund_files
    fund_files.each do |fund_file|
      saved_fund_file = save_fund_file fund_file 
      records = load_fund_file fund_file, saved_fund_file
      if records
        records.each do |record|
          save_record record
        end
      else
        puts "ERROR: no records for #{fund_file.parsed_data_file}"
      end
    end

  end

  def get_direct_link fund_file
    direct_link = if !fund_file.direct_link_to_pdf.blank?
      fund_file.direct_link_to_pdf
    elsif !fund_file.direct_link_to_excel.blank?
      fund_file.direct_link_to_excel
    elsif !fund_file.direct_link_to_html.blank?
      fund_file.direct_link_to_html
    elsif !fund_file.direct_link_to_doc.blank?
      fund_file.direct_link_to_doc
    else
      fund_file.uri_to_landing_page
    end
  end

  def save_fund_file fund_file
    direct_link = get_direct_link fund_file
    attributes = {
        :country => fund_file.country,
        :region => fund_file.region,
        :program => fund_file.program,
        :sub_program => fund_file.sub_program_information,
        :original_file_name => fund_file.original_file_name,
        :parsed_data_file => fund_file.parsed_data_file,
        :direct_link => direct_link
    }
    fund_file_model.create attributes
  end

  def fund_file_model
    eval('FundFile')
  end

  def save_record record
    record_model.create record.morph_attributes
  end

  def record_model
    eval('FundItem')
  end

  def row_not_empty(s, row)
    s.cell(row,1) ? true : false
  end

  def convert excel_file
    sheet = Excel.new(excel_file)
    raise 'expected value in first cell' unless row_not_empty(sheet, 1)
    FasterCSV.generate do |csv|
      1.upto(sheet.last_row) do |row_index|
        row = []
        1.upto(sheet.last_column) do |col|
          row << sheet.cell(row_index, col)
        end
        csv << row
      end
    end
  end

  def convert_to_morph_method_name label
    name = label.to_s.downcase.tr('()\-*',' ').gsub('%','percentage').gsub("'",'_').gsub('/','_').strip.chomp(':').strip.gsub(/\s/,'_').squeeze('_')
    name = '_'+name if name =~ /^\d/
    name.sub!('operación','operacion')
    name
  end

  def load_fund_files file_name
    csv = IO.read(file_name)
    csv.sub!('Excel/PDF','Excel_or_PDF')
    csv.sub!('EU/Nation/Region','EU_or_Nation_or_Region')
    csv.sub!('Sub-region / ','Sub-region_or_')
    fund_files = Morph.from_csv(csv, 'FundFileProxy')
    fund_files.select {|f| !f.parsed_data_file.blank? && !f.parsed_data_file[/no data in pdf/] && !f.parsed_data_file[/^it_/] && !f.parsed_data_file[/pl_allregions_esf.csv/] }
  end

  def field_names fund_file
    attributes = fund_file.class.morph_attributes
    fields = attributes.select{|a| a.to_s[/_field$/]}
    field_names = fields.collect do |field|
      normalized = field.to_s.sub(/_field$/,'').to_sym
      original = convert_to_morph_method_name(fund_file.send(field))
      original = original.to_sym unless original.blank?
      [normalized, original]
    end
    field_names.select {|x| !x[1].blank?}
  end
  
  def attribute_names record
    record.class.morph_attributes
  end
  
  def fund_file_migration
    %Q|./script/destroy scaffold_resource FundFile\n| +
    %Q|./script/generate scaffold_resource FundFile country:string region:string program:string sub_program:string original_file_name:string parsed_data_file:string direct_link:string|
  end

  def fund_item_migration record
    attributes = attribute_names(record)
    attr_definitions = attributes.collect {|a| a.to_s == 'fund_file_id' ? 'fund_file_id:integer' : "#{a.to_s}:string" }
    attributes = (attr_definitions + ['fund_file_id:integer']).uniq.join(' ')
%Q|./script/destroy scaffold_resource FundItem
./script/generate scaffold_resource FundItem #{attributes}|
  end

  def csv_from_file file_name
    return nil if !File.exist?(file_name)
    puts 'opening ' + file_name
    csv = case File.extname(file_name)
    when '.xls'
      convert file_name
    when '.csv'
      IO.read(file_name)
    else
      raise "unexpected file type: #{file_name}"
    end
  end

  def load_fund_file fund_file, saved_fund_file
    name = fund_file.parsed_data_file
    return nil if name.blank?
    country_code = name[0..1]
    file_name = "#{RAILS_ROOT}/DATA/#{country_code}/#{name}"

    csv = csv_from_file(file_name)

    return nil unless csv
    begin
      raw_records = Morph.from_csv csv, 'RawRecord'
    rescue Exception => e
      puts e.class.name
      puts e.to_s
      return nil
    end

    field_names = field_names(fund_file)

    raw_records.collect do |raw|
      record = FundRecord.new
      record.fund_file_id = saved_fund_file.id if saved_fund_file

      field_names.each do |field|
        normalized = field[0]
        original = field[1]
        begin
          value = raw.send(original)
          record.morph(normalized, value)
        rescue Exception => e
          puts e.class.name
          puts e.to_s
          puts raw.inspect          
        end
      end
      record
    end
  end

end
