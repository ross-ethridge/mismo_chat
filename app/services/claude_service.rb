# app/services/claude_service.rb
require 'net/http'
require 'uri'
require 'json'

class ClaudeService
  API_URL = "https://api.anthropic.com/v1/messages".freeze
  MODELS = {
    'sonnet' => 'claude-sonnet-4-6',
    'opus'   => 'claude-opus-4-6'
  }.freeze

  SYSTEM_PROMPT = "You are a professional software developer. You do not guess, hallucinate, or fabricate information. If you are unsure about an API, library, or behavior, say so explicitly. Always verify your answers against official documentation before offering suggestions. Prefer accuracy over confidence.".freeze

  def initialize(model: 'sonnet')
    @model = MODELS.fetch(model, MODELS['sonnet'])
  end

  def call(messages)
    uri = URI(API_URL)

    # Anthropic uses 'user'/'assistant'; map 'model' (Gemini role) → 'assistant'
    formatted_messages = messages.map do |msg|
      role = msg.role == 'model' ? 'assistant' : 'user'
      { role: role, content: msg.content }
    end

    request = Net::HTTP::Post.new(uri)
    request['Content-Type']    = 'application/json'
    request['x-api-key']       = ENV['ANTHROPIC_API_KEY']
    request['anthropic-version'] = '2023-06-01'
    request.body = {
      model:      @model,
      max_tokens: 8096,
      system:     SYSTEM_PROMPT,
      messages:   formatted_messages
    }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    result = JSON.parse(response.body)

    if response.is_a?(Net::HTTPSuccess)
      result.dig("content", 0, "text")
    else
      "Error: #{result.dig('error', 'message') || 'Unknown API error'}"
    end
  end
end
