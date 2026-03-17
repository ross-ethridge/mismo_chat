class ChatsController < ApplicationController
  before_action :set_conversation

  def index
    @messages = @conversation.messages.order(:created_at)
    @conversations = Conversation.order(created_at: :desc)
    @ai_model     = session[:ai_model]     || 'gemini'
    @claude_model = session[:claude_model] || 'sonnet'
    @gemini_model = 'flash'
    session[:gemini_model] = 'flash'
  end

  def create
    user_content = params[:content]
    return redirect_to chats_path if user_content.blank?

    Message.create!(role: 'user', content: user_content, conversation: @conversation)

    # Auto-title from the first user message
    if @conversation.title.blank?
      @conversation.update!(title: user_content.truncate(60))
    end

    history = @conversation.messages.order(:created_at).to_a
    service = if session[:ai_model] == 'claude'
                ClaudeService.new(model: session[:claude_model] || 'sonnet')
              else
                GeminiService.new(model: 'flash')
              end
    ai_response = service.call(history)

    Message.create!(role: 'model', content: ai_response, conversation: @conversation)

    redirect_to chats_path
  end

  private

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
