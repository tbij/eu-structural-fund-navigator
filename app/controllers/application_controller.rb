require 'spreadsheet'
# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details

  before_filter :authenticate

  # Scrub sensitive parameters from your log
  # filter_parameter_logging :password

  def home
    @top_priority = %w[ITALY GERMANY SPAIN GREECE BULGARIA UK] # LATVIA 
    countries = Country.find(:all, :include => :fund_files)

    top_countries = countries.select {|x| @top_priority.include?(x.name) }
    other_countries = countries - top_countries
    @other_priority = other_countries.map(&:name)

    @countries_by_name = countries.group_by(&:name)
    @top_countries_by_name = top_countries.group_by(&:name)
    @other_countries_by_name = other_countries.group_by(&:name)
    
    @loaded_files_by_country = Hash.new {|h,v| h[v] = 0}
    @items_by_country = Hash.new {|h,v| h[v] = 0}
    countries.each do |country|
      country.fund_files.each do |fund_file|
        if fund_file.is_a?(NationalFundFile)
          items_count = fund_file.fund_items.count
          @items_by_country[country.name] += items_count
          @loaded_files_by_country[country.name] += 1 if (items_count > 0)
        end
      end
    end
    @files_by_country = countries.inject({}) {|h,c| h[c.name] = c.fund_files.count; h}
    @file_errors_by_country = countries.inject({}) {|h,c| h[c.name] = c.fund_files.count(:conditions => "error IS NOT NULL"); h}
    @percent_loaded_by_country = @files_by_country.keys.inject({}) do |hash, country|
      hash[country] = 100 * @loaded_files_by_country[country].to_f / @files_by_country[country].to_f
      hash
    end
    @percent_errors_by_country = @files_by_country.keys.inject({}) do |hash, country|
      hash[country] = 100 * @file_errors_by_country[country].to_f / @files_by_country[country].to_f
      hash
    end

    @total_items = FundItem.count
    @total_loaded_files = @loaded_files_by_country.values.sum
    @total_files = @files_by_country.values.sum
    # @total_percent_loaded = 100 * @total_loaded_files.to_f / @total_files.to_f
    @total_file_errors = @file_errors_by_country.values.sum
    # @total_percent_errors = 100 * @total_file_errors.to_f / @total_files.to_f

    @top_items_by_country = @items_by_country.keys.inject({}) do |hash, name|
      hash[name] = @items_by_country[name] if @top_priority.include?(name)
      hash
    end
    @top_total_loaded_files = @top_priority.collect{|name| @loaded_files_by_country[name]}.flatten.sum
    @top_total_files =        @top_priority.collect{|name| @files_by_country[name]}.flatten.sum
    @top_total_file_errors =  @top_priority.collect{|name| @file_errors_by_country[name]}.flatten.sum

    @top_total_percent_loaded = @top_priority.collect {|name| @percent_loaded_by_country[name].to_f }.sum / @top_priority.size
    @top_total_percent_errors = @top_priority.collect {|name| @percent_errors_by_country[name].to_f }.sum / @top_priority.size

    @other_items_by_country = @items_by_country.keys.inject({}) do |hash, name|
      hash[name] = @items_by_country[name] if @other_priority.include?(name)
      hash
    end
    @other_total_loaded_files = @other_priority.collect{|name| @loaded_files_by_country[name]}.flatten.sum
    @other_total_files = @other_priority.collect{|name| @files_by_country[name]}.flatten.sum
    @other_total_file_errors = @other_priority.collect{|name| @file_errors_by_country[name]}.flatten.sum

    @other_total_percent_loaded = @other_priority.collect {|name| @percent_loaded_by_country[name].to_f }.sum / @other_priority.size
    @other_total_percent_errors = @other_priority.collect {|name| @percent_errors_by_country[name].to_f }.sum / @other_priority.size
  end

  def to_csv_file
    country_id = params[:country_id]
    country = Country.find(country_id, :include => {:fund_files => :fund_items})

    fund_files = country.fund_files
    # fund_files = fund_files.select {|f| f.region == 'Calabria'}
    items = fund_files.collect(&:fund_items).flatten

    fund_fields = [
      :region
    ]
    item_fields = [
      :district,
      :beneficiary,
      :project_title,
      :description,
      :amount_allocated_eu_funds_and_public_funds_combined,
      :amount_paid,
      :amount_allocated_eu_funds,
      :amount_allocated_public_funds,
      :amount_allocated_private_funds,
      :amount_allocated_private_funds,
      :year,
      :start_year,
      :sub_program_name
    ]
    item_fields.delete_if do |field|
      non_blank_count = items.collect { |item| item.send(field) }.select { |value| !value.blank? }.size
      delete = (non_blank_count == 0)
    end
    
    all_fields = (fund_fields + [:program] + item_fields + [:direct_link]).map { |field| FundItem.human_attribute_name(field) }

    output = FasterCSV.generate do |csv|
      csv << all_fields
      items.each do |item|
        program = item.european_fund_name.blank? ? item.fund_file.program : item.european_fund_name
        direct_link = item.fund_file.direct_link
        data = fund_fields.collect {|field| item.fund_file.send(field)} + [program] + item_fields.collect { |field| item.send(field) } + [direct_link]
        csv << data
      end
    end

    render :text => output, :content_type => "text/csv"
=begin
    workbook = Spreadsheet::Workbook.new()
    worksheet = workbook.create_worksheet()
    fields = items.first.attributes.keys
    fields.each_with_index do |field, index|
      worksheet[0, index] = field
    end
    
    items.each_with_index do |item, index|
      attributes = item.attributes
      row = index + 1
      fields.each_with_index do |field, col|
        worksheet[row, col] = attributes[field]
      end
    end

    file_name = "#{RAILS_ROOT}/public/#{country.name.tableize.singularize}.xls"
    logger.info file_name
    workbook.write(file_name)

    # render :excel => proc { |response, output| output.write(IO.read(file_name)) }
    render :file => file_name, :content_type => "application/vnd.ms-excel"
=end
  end

  private
  def authenticate
    auth = YAML.load_file(RAILS_ROOT+'/config/auth.yml')
    auth.symbolize_keys!
    authenticate_or_request_with_http_basic do |id, password|
      id == auth[:user] && password == auth[:password]
    end
  end
end
