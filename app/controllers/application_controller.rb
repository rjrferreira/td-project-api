require 'net/http'

class ApplicationController < ActionController::API

  #README

  # call to external API
    # validate errors
    # if the endpoint is unreachanble (without internet for example)

  # LOGGING TO FILE

  # Tests

  def aggregate
    result = {}

    if request.body.string.blank? #params["_json"]
      logger.info "Empty phones list"
      render json: {status: "error", code: 400, message: "Phones list is required"}
    else
      phones_list = JSON.parse(request.body.string)

      phones_list.each do |phone|

        # TODO validate Number
        # For invalid numbers, the API replies with a bad request status code. A number is considered valid if it contains only digits, an optional leading + and
        # whitespace anywhere except immediately after the +. A valid number has exactly 3 digits or more than 6 and less than 13. 00 is acceptable as replacement for the leading +.

        begin
          api_phone_response = Rails.cache.fetch("sector/#{phone}", expires_in: 24.hours) do
            call_business_sector_api phone
          end
        rescue Exception => e
          render json: {status: "error", code: 503, message: e.message}
          return
        end

        if api_phone_response.code == "200"
          phone_specification = JSON.parse(api_phone_response.body)

          # Get Prefix
          prefix = retrive_prefix phone

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

      end

      render json: result

    end

  end


  private

  def fix_plus_symbol phone
    phone.starts_with?("+") ? phone.gsub("+", "") : phone
  end

  def fix_double_zero phone
    phone.starts_with?("00") ? phone.sub("00", "") : phone
  end

  def retrive_prefix phone
    phone_changed = fix_plus_symbol phone
    phone_changed = fix_double_zero phone_changed
    PREFIXES.each do |p|
      return p.strip if phone_changed.starts_with?(p.strip) #remove newline char with strip
    end
    logger.info "Invalid number: #{phone} (Prefix unknown)"
    ""
  end

  def call_business_sector_api phone
    begin
      uri = URI.encode("https://challenge-business-sector-api.meza.talkdeskstg.com/sector/#{phone}")
      uri = URI.parse(uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.get(uri.request_uri)
    rescue Exception => e
      logger.error "Unable connect to the following url: #{uri}"
      logger.error e.message
      raise Exception.new('Unable connect to host')
    end

  end

end
