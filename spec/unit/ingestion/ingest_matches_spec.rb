require_relative '../../ingestion/ingest_matches'
require_relative '../spec_helper'

RSpec.describe IngestMatches do

  before do
    allow(HTTParty).to receive(:get).and_return(tba_response)
    allow(Aws::S3::Client).to receive(:new).and_return(s3_client)
    allow(Time).to receive(:now).and_return(time)
  end

  let(:time) { Time.new(2020) }

  let(:frc_event_code) { "fake_event_code" }

  let(:event) { { "pathParameters" => { "frc_event_code" => frc_event_code } } }

  let(:response) { described_class.handler(:event => event, :context => nil) }
  let(:s3_client) { instance_double(Aws::S3::Client) }

  describe "handler" do
    context "when TBA returns an error" do
      let(:frc_event_code) { "" }
      let(:tba_response) { instance_double(HTTParty::Response, :body => "foo", :code => 200) }

      it "does not write to s3 and returns a 400 error" do
        expect(s3_client).not_to receive(:put_object)
        expect(response).to eq({:statusCode => 400, :body => { :message => "Request must include frc_event_code in path parameters" }.to_json } )
      end
    end

    context "when TBA returns an error" do
      let(:error_message) { "foo" }
      let(:tba_response) { instance_double(HTTParty::Response, :body => error_message, :code => 401) }

      it "does not write to s3 and returns a 500 error" do
        expect(s3_client).not_to receive(:put_object)
        expect(response).to eq({:statusCode => 500, :body => { :message => "Error fetching from TBA: #{error_message}" }.to_json } )
      end
    end

    context "when TBA returns succesfully" do
      let(:tba_response) { instance_double(HTTParty::Response, :body => "foo", :code => 200) }

      it "writes to s3 and returns a 200 success" do
        expect(s3_client).to receive(:put_object)
        .with(
          :bucket => ENV["INTERNAL_STORAGE_BUCKET"],
          :key => "raw_data/event_code=#{frc_event_code}/fetch_time=#{time.to_i}/matches.json",
          :body => tba_response.body
        )
        expect(response).to eq({:statusCode => 200, :body => { :message => "Success" }.to_json } )
      end
    end
  end
end
