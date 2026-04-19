require "net/http"
require "uri"
require "json"

class ImagenService
  SD_URL = "http://sd:8000/generate".freeze

  # Returns raw PNG bytes on success, raises RuntimeError on failure
  def call(prompt, width: nil, height: nil)
    uri = URI(SD_URL)

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    body = { prompt: prompt }
    body[:width]  = width  if width
    body[:height] = height if height
    request.body = body.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, read_timeout: 120) do |http|
      http.request(request)
    end

    unless response.is_a?(Net::HTTPSuccess)
      error = JSON.parse(response.body).dig("detail") rescue response.body
      raise error || "Unknown SD error"
    end

    response.body
  end
end
