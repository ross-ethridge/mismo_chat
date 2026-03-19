class ChatsController < ApplicationController
  before_action :set_conversation

  def index
    @messages = @conversation.messages.order(:created_at)
    @conversations = Conversation.order(created_at: :desc)
    @ai_model     = session[:ai_model]     || "gemini"
    @claude_model = session[:claude_model] || "sonnet"
    @gemini_model = "flash"
    session[:gemini_model] = "flash"
  end

  def create
    user_content = params[:content]
    return redirect_to chats_path if user_content.blank?

    Message.create!(role: "user", content: user_content, conversation: @conversation)

    # Auto-title from the first user message
    if @conversation.title.blank?
      @conversation.update!(title: user_content.truncate(60))
    end

    history = @conversation.messages.order(:created_at).to_a
    service = if session[:ai_model] == "claude"
                ClaudeService.new(model: session[:claude_model] || "sonnet")
    else
                GeminiService.new(model: "flash")
    end
    ai_response = service.call(history)

    if (image_prompt = extract_image_prompt(ai_response))
      begin
        image_bytes = ImagenService.new.call(image_prompt)
        image_data  = Base64.strict_encode64(image_bytes)
        Message.create!(role: "model", content: "[Image: #{image_prompt}]", image_data: image_data, conversation: @conversation)
      rescue => e
        Message.create!(role: "model", content: "I tried to generate an image but the image service returned an error: #{e.message}", conversation: @conversation)
      end
    else
      Message.create!(role: "model", content: ai_response, conversation: @conversation)
    end

    redirect_to chats_path
  end

  private

  def extract_image_prompt(response)
    parsed = JSON.parse(response.to_s.strip)
    parsed["image_prompt"] if parsed.is_a?(Hash) && parsed.key?("image_prompt")
  rescue JSON::ParserError
    nil
  end

  def set_conversation
    if params[:conversation_id].present?
      session[:conversation_id] = params[:conversation_id].to_i
    end

    @conversation = Conversation.find_by(id: session[:conversation_id])

    if @conversation.nil?
      @conversation = Conversation.create!
      session[:conversation_id] = @conversation.id
    end
  end
end
