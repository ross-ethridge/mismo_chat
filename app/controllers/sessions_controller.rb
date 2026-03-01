class SessionsController < ApplicationController
  def update
    session[:ai_model]     = params[:ai_model]     if params[:ai_model].present?
    session[:claude_model] = params[:claude_model] if params[:claude_model].present?
    session[:gemini_model] = params[:gemini_model] if params[:gemini_model].present?
    redirect_back fallback_location: chats_path
  end
end
