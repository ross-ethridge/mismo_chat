require "net/http"
require "uri"
require "json"

class PromptEnhancerService
  SYSTEM_PROMPT = "You are an expert Stable Diffusion prompt engineer. Given a user's image description, respond with ONLY a detailed, optimized Stable Diffusion image generation prompt. Include relevant art style, lighting, composition, and quality modifiers. Output nothing else — just the raw prompt text with no preamble or explanation.".freeze

  def initialize(provider: "claude")
    @provider = provider
  end

  def call(description)
    case @provider
    when "gemini" then call_gemini(description)
    else call_claude(description)
    end
  end

  private

  def call_claude(description)
    uri = URI("https://api.anthropic.com/v1/messages")
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"]      = "application/json"
    request["x-api-key"]         = ENV["ANTHROPIC_API_KEY"]
    request["anthropic-version"] = "2023-06-01"
    request.body = {
      model:      "claude-sonnet-4-6",
      max_tokens: 512,
      system:     SYSTEM_PROMPT,
      messages:   [ { role: "user", content: description } ]
    }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |h| h.request(request) }
    result   = JSON.parse(response.body)

    if response.is_a?(Net::HTTPSuccess)
      result.dig("content", 0, "text")
    else
      raise "Claude error: #{result.dig('error', 'message') || 'unknown'}"
    end
  end

  def call_gemini(description)
    model = "gemini-3.1-flash-lite-preview"
    uri   = URI("https://generativelanguage.googleapis.com/v1beta/models/#{model}:generateContent?key=#{ENV['GEMINI_API_KEY']}")
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request.body = {
      system_instruction: { parts: [ { text: SYSTEM_PROMPT } ] },
      contents:           [ { role: "user", parts: [ { text: description } ] } ]
    }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |h| h.request(request) }
    result   = JSON.parse(response.body)

    if response.is_a?(Net::HTTPSuccess)
      result.dig("candidates", 0, "content", "parts", 0, "text")
    else
      raise "Gemini error: #{result.dig('error', 'message') || 'unknown'}"
    end
  end
end
