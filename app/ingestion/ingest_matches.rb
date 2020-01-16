require 'httparty'
require 'json'
require 'aws-sdk-s3'

class IngestMatches
  TBA_BASE_URL = "http://thebluealliance.com/api/v3"

  def self.handler(event:, context:)

    frc_event_code = event.fetch("pathParameters")&.fetch("frc_event_code")

    if frc_event_code.empty?
      return {
        :statusCode => 400,
        :body => {
          :message => "Request must include frc_event_code in path parameters",
        }.to_json
      }
    end

    matches_response = HTTParty.get("#{TBA_BASE_URL}/event/#{frc_event_code}/matches",
      :headers => { "X-TBA-Auth-Key" => ENV["TBA_API_KEY"] }
    )

    if matches_response.code != 200
      return {
        :statusCode => 500,
        :body => {
          :message => "Error fetching from TBA: #{matches_response.body}",
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

    s3.put_object(:bucket => ENV["INTERNAL_STORAGE_BUCKET"], :key => "raw_data/event_code=#{frc_event_code}/fetch_time=#{time.to_i}/matches.json", :body => matches_response.body)

    {
      statusCode: 200,
      body: {
        message: "Success"
      }.to_json
    }
  end
end
