require 'net/http'

class ApplicationController < ActionController::API

  include AggregationHelper

  def aggregate
    result = {}

    if request.body.string.blank? #params["_json"]
      logger.info "Empty phones list"
      render json: {status: "error", code: 400, message: "Phones list is required"}
    else
      phones_list = JSON.parse(request.body.string)

      phones_list.each do |phone|

        # Validate Phone Number
        if valid_phone(phone)
          begin
            api_phone_response = Rails.cache.fetch("sector/#{phone.delete(" ")}", expires_in: 24.hours) do
              call_business_sector_api phone
            end
          rescue Exception => e
            render json: {status: "error", code: 503, message: e.message}
            return
          end

          if api_phone_response.code == "200"
            phone_specification = JSON.parse(api_phone_response.body)

            # Get Prefix
            prefix = retrieve_prefix phone

            unless prefix.blank?
              # Create Hash for prefix if no exists
              result[prefix] = {} unless result.key?(prefix)

              # Fill Inner Hash for prefix
              if result[prefix][phone_specification["sector"]].blank?
                result[prefix][phone_specification["sector"]] = 1
              else
                result[prefix][phone_specification["sector"]] += 1
              end
            end

          else
            logger.error "#{api_phone_response.code} - #{api_phone_response.message} - phone number #{phone}"
          end
        else
          logger.info "Invalid phone number #{phone}"
        end

      end

      render json: result
    end

  end

end
