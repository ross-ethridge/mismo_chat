require "net/http"
require "uri"
require "json"

class OllamaService
  HOST = ENV.fetch("OLLAMA_HOST", "http://host.docker.internal:11434")

  SYSTEM_PROMPT = ClaudeService::SYSTEM_PROMPT

  def initialize(model:)
    @model = model
  end

  def call(messages)
    uri = URI("#{HOST}/api/chat")

    formatted = messages.map do |msg|
      role = msg.role == "model" ? "assistant" : msg.role
      { role: role, content: msg.content }
    end

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request.body = {
      model: @model,
      stream: false,
      keep_alive: -1,
      messages: [ { role: "system", content: SYSTEM_PROMPT } ] + formatted
    }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 120) do |http|
      http.request(request)
    end

    result = JSON.parse(response.body)

    if response.is_a?(Net::HTTPSuccess)
      result.dig("message", "content")
    else
      "Error: #{result["error"] || "Unknown Ollama error"}"
    end
  rescue Errno::ECONNREFUSED, Net::OpenTimeout => e
    "Error: Could not connect to Ollama (#{e.message})"
  end

  def self.available_models
    uri = URI("#{HOST}/api/tags")
    response = Net::HTTP.get_response(uri)
    JSON.parse(response.body).fetch("models", []).map { |m| m["name"] }.sort
  rescue
    []
  end

  def self.running_models
    uri = URI("#{HOST}/api/ps")
    response = Net::HTTP.get_response(uri)
    JSON.parse(response.body).fetch("models", []).map { |m| m["name"] }
  rescue
    []
  end

  def self.preload(model)
    Thread.new do
      uri = URI("#{HOST}/api/generate")
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request.body = { model: model, prompt: "", keep_alive: -1 }.to_json
      Net::HTTP.start(uri.hostname, uri.port, open_timeout: 5, read_timeout: 60) { |h| h.request(request) }
    rescue
      # best-effort warm-up
    end
  end
end
