# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
class ApplicationController < ActionController::Base

  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details

  before_filter :authenticate

  # caches_action :to_csv_file

  # Scrub sensitive parameters from your log
  # filter_parameter_logging :password

  def home
  end

  def translate_and_search
    if query = params['q']
      region = params[:fund_region]
      country = params[:fund_country]
      page = params[:page] || 1
      per_page = 15

      @search = Search.new(logger, page, per_page, region, country)
      results = @search.translate_and_search(query)

      @countries = @search.countries
      @regions   = @search.regions
      @total_results = @search.total
      @current_page = @search.current_page
      @total_pages = @search.total_pages
      @results = @search.results
      @query = @search.joined_terms
      @result_set = @search.largest_result_set
      @min_eu_amount_in_euros = @search.min_eu_amount_in_euros
      @amount_estimated_eu_funding_in_euro = @search.amount_estimated_eu_funding_in_euro
      params['q'] = @query

      if params['f'] == 'csv'
        output_csv(@search.all_results)
      else
        @search_results = true
        render :template => 'application/search'
      end
    else
      render :template => 'application/home'
    end
  end

  def search
    if query = params['q']
      region = params[:fund_region]
      country = params[:fund_country]
      page = params[:page] || 1
      per_page = 15
      search = Search.new(logger, page, per_page, region, country)
      result = search.do_search(query)
      @countries = result.facet(:fund_country).rows
      @regions = result.facet(:fund_region).rows

      @results = []
      result.each_hit_with_result {|hit, item| @results << item}
      @total_results = result.total
      @current_page = result.hits.current_page
      @total_pages = result.hits.total_pages

      @query = query
      if params['f'] == 'csv'
        output_csv(@results)
      else
        @search_results = true
      end
    else
      render :template => 'application/home'
    end
  end

  def dashboard
    @top_priority = %w[FRANCE GERMANY GREECE ITALY ROMANIA SPAIN UK] # LATVIA BULGARIA
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
    @files_by_country = countries.inject({}) {|h,c| h[c.name] = c.national_fund_files_count; h}
    @file_errors_by_country = countries.inject({}) {|h,c| h[c.name] = c.fund_files.count(:conditions => 'error IS NOT NULL AND type = "NationalFundFile"'); h}
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
    @total_file_errors = @file_errors_by_country.values.sum

    @top_items_by_country = @items_by_country.keys.inject({}) do |hash, name|
      hash[name] = @items_by_country[name] if @top_priority.include?(name)
      hash
    end

    @top_items_count = @top_items_by_country.values.map(&:to_i).sum
    @top_total_loaded_files = @top_priority.collect{|name| @loaded_files_by_country[name]}.flatten.sum
    @top_total_files =        @top_priority.collect{|name| @files_by_country[name] || 0}.flatten.sum
    @top_total_file_errors =  @top_priority.collect{|name| @file_errors_by_country[name] || 0}.flatten.sum
    @top_error_colour = (@top_total_file_errors == 0) ? 'darkgrey' : 'darkred'

    @top_total_percent_loaded = @top_priority.collect {|name| @percent_loaded_by_country[name].to_f }.sum / @top_priority.size
    @top_total_percent_errors = @top_priority.collect {|name| @percent_errors_by_country[name].to_f }.sum / @top_priority.size

    @other_items_by_country = @items_by_country.keys.inject({}) do |hash, name|
      hash[name] = @items_by_country[name] if @other_priority.include?(name)
      hash
    end

    @other_countries = @other_items_by_country.keys.compact.sort
    @other_items_count =        @other_items_by_country.values.map(&:to_i).sum
    @other_total_loaded_files = @other_countries.collect{|name| @loaded_files_by_country[name]}.flatten.sum
    @other_total_files =        @other_countries.collect{|name|        @files_by_country[name]}.flatten.sum
    @other_total_file_errors =  @other_countries.collect{|name|  @file_errors_by_country[name]}.flatten.sum
    @other_error_colour = (@other_total_file_errors == 0) ? 'darkgrey' : 'darkred'

    other_priority_size = @other_countries.size
    other_priority_size = 1 if other_priority_size == 0

    @other_total_percent_loaded = @other_countries.collect {|name| @percent_loaded_by_country[name].to_f }.sum / other_priority_size
    @other_total_percent_errors = @other_countries.collect {|name| @percent_errors_by_country[name].to_f }.sum / other_priority_size

    transnational = countries.select {|c| c.transnational_fund_files_count > 0}
    @transnational_groups = transnational.map(&:name).sort
    @transnational_by_country = transnational.inject({}) {|h,c| h[c.name] = (c.transnational_fund_files_count); h}
    @transnational_total_files = @transnational_groups.collect{|name| @transnational_by_country[name] || 0}.flatten.sum

    crossborder = countries.select {|c| c.crossborder_fund_files_count > 0}
    @crossborder_groups = crossborder.map(&:name).sort
    @crossborder_by_country = crossborder.inject({}) {|h,c| h[c.name] = (c.crossborder_fund_files_count); h}
    @crossborder_total_files = @crossborder_groups.collect{|name| @crossborder_by_country[name] || 0}.flatten.sum
  end

  def errors_by_country
    name = params[:country_name]
    country = Country.find_by_name(name, :include => :fund_files)
    @country_name = name.split.map(&:capitalize).join(' ')
    @files_with_errors = country.fund_files.compact.select(&:error)
  end

  def create_csv fund_files, country, tmpfile
    include_header = true

    fund_files.each do |fund_file|
      ids = FundItem.find_by_sql('select id from fund_items where fund_file_id = "' + fund_file.id.to_s + '"').map(&:id)

      ids.in_groups_of(1000).each do |id_group|
        id_group = id_group.compact
        items = FundItem.find(:all, :conditions => "id in (#{id_group.join(',')})")
        csv_string = CsvHelper.get_csv(items, fund_files, include_header)
        include_header = false
        tmpfile.write csv_string
        tmpfile.flush
      end
    end
  end

  def eufunds_csv
    path = "#{DataLoader.eufunds_csv}.zip"
    send_file path, :type => "text/plain", :filename=>"eufunds.csv.zip", :disposition => 'attachment'
  end

  def to_csv_file
    tmpfile = nil
    datetime = "#{Date.today.to_s}_#{Time.now.to_s(:short)[-5..-1].sub(':','')}"
    path = File.join(File.expand_path(Dir::tmpdir), "items_#{datetime}_#{Time.now.to_i}")
    begin
      require 'tempfile'
      tmpfile = File.new(path, 'w')
      name = nil
      country_id = params[:country_id]
      if country_id.to_i == 0
        fund_files = FundFile.find(:all)
        create_csv fund_files, country=nil, tmpfile
        name = 'all_countries'
      else
        country = Country.find(country_id, :include => :fund_files )
        name = country.name.downcase
        fund_files = country.fund_files
        create_csv fund_files, country, tmpfile
      end
      tmpfile.close

      send_file path, :type => "text/plain", :filename=>"#{name}_#{datetime}.csv", :disposition => 'attachment'
    ensure
      tempfiles = Dir.glob(File.join(File.expand_path(Dir::tmpdir), "items_*"))
      tempfiles.each do |file|
        file_older_than_a_day = ((Time.now - File.ctime(file)) > 1.day)
        File.delete(file) if file_older_than_a_day
      end
    end
  end

  private

  def output_csv items, fund_files=nil, country=nil
    csv_string = CsvHelper.get_csv(items, fund_files, true)
    send_data csv_string, :type => "text/plain", :filename=>"items.csv", :disposition => 'attachment'
  end

  def authenticate
    auth = YAML.load_file(RAILS_ROOT+'/config/auth.yml')
    auth.symbolize_keys!
    authenticate_or_request_with_http_basic do |id, password|
      id == auth[:user] && password == auth[:password]
    end
  end

end
