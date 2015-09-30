require 'sinatra'
require 'json'
require 'rest_client'

# Constants
SECRET_TOKEN = ENV['SECRET_TOKEN']
SLACK_URL = ENV['SLACK_URL']

# Webhook endpoint
post '/hooks' do
  # Grab our payload
  request.body.rewind
  payload_body = request.body.read

  # Verify our signature is coming from Github
  verify_signature(payload_body)

  @payload = JSON.parse(payload_body)

  # A webhook has been received from Github
  case request.env['HTTP_X_GITHUB_EVENT']
  when "release"
    if (@payload["action"] == "published") && (@payload["release"]["draft"] == false)
      process_release(@payload)
    end
  end
end

# Helper methods
helpers do

  def process_release(payload)
    url = payload['release']['html_url']
    name = payload['release']['name']
    body = payload['release']['body']
    repo_name = payload['repository']['full_name']

    payload = {:attachments => [
                {
                  :fallback => "[" + repo_name + "] <" + url + "|New Release!>",
                  :pretext => "[" + repo_name + "] <" + url + "|New Release!>",
                  :color => "good",
                  :fields => [{
                    :title => name,
                    :title_link => url,
                    :value => body,
                    :short => false
                  }]
                }
              ]}

    begin
      RestClient.post(SLACK_URL, payload.to_json)
    rescue => e
      e.response
    end


    return 200
  end

  # Ensure the delivered webhook is from Github
  def verify_signature(payload_body)
    signature = 'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), SECRET_TOKEN, payload_body)
    return halt 500, "Signatures didn't match!" unless Rack::Utils.secure_compare(signature, request.env['HTTP_X_HUB_SIGNATURE'])
  end
end