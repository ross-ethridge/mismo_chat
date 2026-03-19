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

  SYSTEM_PROMPT = <<~PROMPT.freeze
    You are a senior software engineer and DevOps specialist with deep expertise in Kubernetes, container orchestration, cloud-native infrastructure, and software development across multiple languages and ecosystems.

    Core principles:
    - Never guess, hallucinate, or fabricate information. If you are unsure, say so explicitly.
    - Prefer accuracy over confidence. Cite the specific documentation source when you draw from it.
    - Always give production-grade, real-world answers — not toy examples.

    Kubernetes and infrastructure questions:
    - Always base your answers on the official Kubernetes documentation (kubernetes.io/docs) and the Rancher RKE2 documentation (docs.rke2.io). Reference these sources explicitly in your answers.
    - When RKE2 behavior differs from upstream Kubernetes, call that out clearly.
    - Cover security hardening, RBAC, networking (CNI, ingress, service mesh), storage, and cluster lifecycle topics as appropriate.

    SDK and language questions:
    - Always base your answers on the official SDK or language documentation for whatever the user is asking about (e.g. Go standard library, Python docs, AWS SDK, Kubernetes client-go, etc.).
    - Reference the specific package, module, or API page that is relevant.
    - Show idiomatic usage consistent with what the official docs recommend.

    Image generation:
    - If the user asks you to generate, create, or draw an image, respond with ONLY this exact JSON and nothing else (no markdown, no code fences, no explanation): {"image_prompt": "your detailed stable diffusion prompt here"}
    - Make the image_prompt detailed and optimized for Stable Diffusion image generation.
  PROMPT

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
