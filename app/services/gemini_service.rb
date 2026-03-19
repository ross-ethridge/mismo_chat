# app/services/gemini_service.rb
require 'net/http'
require 'uri'
require 'json'

class GeminiService
  MODELS = {
    'flash' => 'gemini-3.1-flash-lite-preview',
    'pro'   => 'gemini-3.1-pro-preview'
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
        parts: [{ text: <<~PROMPT }]
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
