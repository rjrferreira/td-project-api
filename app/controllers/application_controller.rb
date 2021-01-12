require 'net/http'

class ApplicationController < ActionController::API

  #README

  # call to external API
    # validate errors
    # if the endpoint is unreachanble (without internet for example)

  # LOGGING TO FILE

  # Tests

  #curl -d '["+1983236248"]' "http://localhost:3000/aggregate"

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


  private

  def remove_plus_symbol phone
    phone.starts_with?("+") ? phone.gsub("+", "") : phone
  end

  def remove_double_zero phone
    phone.starts_with?("00") ? phone.sub("00", "") : phone
  end

  def valid_phone phone
    phone = phone.strip #remove leading and trailing whitespace
    return false if !(phone.starts_with?("+") || phone.starts_with?("00"))  #return false - 00 is acceptable as replacement for the leading +
    return false if phone.starts_with?("+ ") #return false if whitespace immediately after the +

    phone = remove_plus_symbol phone
    phone = remove_double_zero phone
    phone = phone.delete(" ") #delete whitespaces

    if (phone =~ /\A\d+\Z/) == 0 # only numbers
      #phone = phone.sub(prefix, "") #remove prefix
      if phone.length == 3
        return true
      elsif phone.length >= 6 && phone.length <= 13
        return true
      end
    else
      return false
    end

    return false
  end

  def retrieve_prefix phone
    phone = phone.strip() #remove leading and trailing whitespace
    phone = remove_plus_symbol phone
    phone = remove_double_zero phone
    PREFIXES.each do |prefix|
      return prefix.strip if phone.starts_with?(prefix)
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
