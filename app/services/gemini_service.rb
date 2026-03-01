# app/services/gemini_service.rb
require 'net/http'
require 'uri'
require 'json'

class GeminiService
  MODELS = {
    'flash' => 'gemini-2.5-flash',
    'pro'   => 'gemini-3.1-pro'
  }.freeze

  def initialize(model: 'flash')
    @model = MODELS.fetch(model, MODELS['flash'])
  end

  def call(messages)
    uri = URI("https://generativelanguage.googleapis.com/v1beta/models/#{@model}:generateContent?key=#{ENV['GEMINI_API_KEY']}")
    
    # Format the database messages into the JSON schema Google Studio expects
    formatted_contents = messages.map do |msg|
      {
        role: msg.role, # 'user' or 'model'
        parts:[{ text: msg.content }]
      }
    end

    # Build the HTTP POST request
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = {
      system_instruction: {
        parts: [{ text: "You are a professional software developer. You do not guess, hallucinate, or fabricate information. If you are unsure about an API, library, or behavior, say so explicitly. Always verify your answers against official documentation before offering suggestions. Prefer accuracy over confidence." }]
      },
      contents: formatted_contents
    }.to_json

    # Execute the request
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    result = JSON.parse(response.body)
    
    # Return the text response or surface an error
    if response.is_a?(Net::HTTPSuccess)
      result.dig("candidates", 0, "content", "parts", 0, "text")
    else
      "Error: #{result.dig('error', 'message') || 'Unknown API error'}"
    end
  end
end
