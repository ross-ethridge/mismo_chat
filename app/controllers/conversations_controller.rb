class ConversationsController < ApplicationController
  def create
    conversation = Conversation.create!
    session[:conversation_id] = conversation.id
    redirect_to chats_path
  end

  def destroy
    conversation = Conversation.find(params[:id])
    conversation.destroy
    if session[:conversation_id] == conversation.id
      session[:conversation_id] = Conversation.order(created_at: :desc).first&.id
    end
    redirect_to chats_path
  end
end
