require 'roo'
require 'morph'

class FundRecord
  include Morph
end

class DataLoader

  def load_database file_name
    fund_files = load_fund_files file_name
    reset_database fund_files.first
    populate_database fund_files
  end
  
  def cmd line
    puts line
    puts `#{line}`
  end
  
  def reset_database fund_file
    migration(fund_file).each_line do |line|
      cmd line.strip
    end
  end
  
  def populate_database fund_files
    fund_files.each do |fund_file|
      records = load_fund_file fund_file
      records.each do |record|
        save_record record
      end
    end
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
    name = label.to_s.downcase.tr('()\-*',' ').gsub('%','percentage').strip.chomp(':').strip.gsub(/\s/,'_').squeeze('_')
    name = '_'+name if name =~ /^\d/
    name
  end

  def load_fund_files file_name
    csv = IO.read(file_name)
    csv.sub!('Excel/PDF','Excel_or_PDF')
    Morph.from_csv csv, 'FundFile'
  end

  def field_names fund_file
    attributes = fund_file.class.morph_attributes
    fields = attributes.select{|a| a.to_s[/_field$/]}
    fields.collect do |field|
      normalized = field.to_s.sub(/_field$/,'').to_sym
      original = convert_to_morph_method_name(fund_file.send(field)).to_sym
      [normalized, original]
    end
  end
  
  def attribute_names record
    record.class.morph_attributes
  end
  
  def migration record
    attributes = attribute_names(record)
    attributes = attributes.collect {|a| "#{a.to_s}:string" }.join(' ')
%Q|
./script/destroy scaffold_resource FundItem
./script/generate scaffold_resource FundItem #{attributes}
rake db:reset
|    
  end

  def get_csv file_name
    csv = case File.extname(file_name)
    when '.xls'
      convert file_name
    when '.csv'
      IO.read(file_name)
    else
      raise "unexpected file type: #{file_name}"
    end
  end

  def load_fund_file fund_file
    name = fund_file.parsed_data_file
    country_code = name[0..1]
    file_name = "#{RAILS_ROOT}/data/#{country_code}/#{name}"

    csv = get_csv(file_name)

    raw_records = Morph.from_csv csv, 'RawRecord'
    
    field_names = field_names(fund_file)
    
    raw_records.collect do |raw|
      record = FundRecord.new
      record.country = fund_file.country
      record.region = fund_file.region
      record.program = fund_file.program
      field_names.each do |field|
        normalized = field[0]
        original = field[1]
        value = raw.send(original)
        record.morph(normalized, value)
      end
      record
    end
  end

end
