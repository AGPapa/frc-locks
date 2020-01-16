require 'httparty'
require 'json'
require 'aws-sdk-s3'

class IngestTBAEndpoint
  TBA_BASE_URL = "http://thebluealliance.com/api/v3"

  def self.handler(event:, context:)

    api_code = event.fetch("pathParameters")&.fetch("api_code")&.replace('-','/')

    if api_code.empty?
      return {
        :statusCode => 400,
        :body => {
          :message => "Request must include api_code in path parameters",
        }.to_json
      }
    end

    tba_response = HTTParty.get("#{TBA_BASE_URL}/#{api_code}",
      :headers => { "X-TBA-Auth-Key" => ENV["TBA_API_KEY"] }
    )

    if tba_response.code != 200
      return {
        :statusCode => 500,
        :body => {
          :message => "Error fetching from TBA: #{tba_response.body}",
        }.to_json
      }
    end

    s3 = Aws::S3::Client.new(
      :region => 'us_east_1',
      :access_key_id => ENV["AWS_ACCESS_KEY_ID"],
      :secret_access_key => ENV["AWS_SECRET_ACCESS_KEY"],
      :endpoint => ENV["S3_ENDPOINT"],
      :force_path_style => true
    )

    time = Time.now

    s3.put_object(:bucket => ENV["INTERNAL_STORAGE_BUCKET"], :key => "raw_data/api_code=#{api_code}/fetch_time=#{time.to_i}/results.json", :body => tba_response.body)

    {
      statusCode: 200,
      body: {
        message: "Success"
      }.to_json
    }
  end
end
