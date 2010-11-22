require 'fastercsv'

class CsvHelper

  def self.get_csv items, fund_files=nil, include_header=false
    fund_files = items.collect(&:fund_file).uniq unless fund_files
    fund_fields = [
      :country,
      :region,
      # :program,
      :operational_program,
      :op_name,
      :co_financing_rate
    ]
    # fund_fields.delete_if do |field|
      # non_blank_count = fund_files.collect { |fund_file| fund_file.send(field) }.select { |value| !value.blank? }.size
      # delete = (non_blank_count == 0)
    # end

    item_fields = [
      :sub_region_or_county,
      :district,
      :beneficiary,
      :normalized_beneficiary,
      :subcontractor,
      :project_title,
      :classification_category,
      :sector_code,
      :parent_company_or_owner,
      :trade_description,
      :ft_category,
      :description,
      :operational_program_name,

      :amount_estimated_eu_funding_in_euro,
      :amount_paid_in_euro,
      :amount_allocated_eu_funds_in_euro,
      :amount_allocated_eu_funds_and_public_funds_combined_in_euro,
      :amount_allocated_public_funds_in_euro,
      :amount_allocated_private_funds_in_euro,
      :amount_allocated_voluntary_funds_in_euro,
      :amount_allocated_other_public_funds_in_euro,
      :amount_total_project_cost_in_euro,
      :amount_unknown_source_in_euro,
      :amount_eligible_in_euro,

      :currency,
      :amount_estimated_eu_funding,
      :amount_paid,
      :amount_allocated_eu_funds,
      :amount_allocated_eu_funds_and_public_funds_combined,
      :amount_allocated_public_funds,
      :amount_allocated_private_funds,
      :amount_allocated_voluntary_funds,
      :amount_allocated_other_public_funds,
      :amount_total_project_cost,
      :amount_unknown_source,
      :amount_eligible,

      :intermediate_body,
      :date,
      :year,
      :start_year,
      :final_payment_year,
      :sub_program_name,
      :sub_sub_program_name,
      :objective,
      :category,
      :legal_entity,
      :match_funded,
      :eu_fund_percentage
    ]

    fund_fields_suffix = [
      :sub_program_information,
      :min_percent_funded_by_eu_funds,
      :max_percent_funded_by_eu_funds,
      :next_update,
      :parsed_data_file,
      :original_file_name,
      :direct_link,
      :uri_to_landing_page
    ]
    # item_fields.delete_if do |field|
      # non_blank_count = items.collect { |item| item.send(field) }.select { |value| !value.blank? }.size
      # delete = (non_blank_count == 0)
    # end

    all_fields = (fund_fields + [:program] + item_fields + fund_fields_suffix).map { |field| FundItem.human_attribute_name(field) }

    output = FasterCSV.generate do |csv|
      csv << all_fields if include_header
      items.each do |item|
        fund_file = item.fund_file
        program = item.european_fund_name.blank? ? fund_file.program : item.european_fund_name
        data = fund_fields.collect do |field|
          fund_file.send(field)
        end
        data += [program]
        data += item_fields.collect do |field|
          begin
            item.send(field)
          rescue NoMethodError
            nil
          end
        end
        data += fund_fields_suffix.collect do |field|
          fund_file.send(field)
        end
        csv << data
      end
    end
  end

end
