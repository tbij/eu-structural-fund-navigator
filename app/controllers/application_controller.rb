# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details

  before_filter :authenticate

  # Scrub sensitive parameters from your log
  # filter_parameter_logging :password

  def home
    @items_by_country = FundItem.count(:group => :country)
    @total_items = FundItem.count
    countries = @items_by_country.keys
    @files_by_country = countries.inject({}) do |hash, country|
      hash[country] = FundItem.count_by_sql(%Q|select count(distinct(original_file_name)) from fund_items where country = "#{country}"|)
      hash
    end
    @total_files = @files_by_country.values.sum
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
