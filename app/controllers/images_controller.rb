class ImagesController < ApplicationController
  def new
  end

  def ai_prompt
    description = params[:description].to_s.strip
    provider    = params[:provider].to_s.downcase
    provider    = "claude" unless %w[claude gemini].include?(provider)

    return render json: { error: "Description required" }, status: 422 if description.blank?

    prompt = PromptEnhancerService.new(provider: provider).call(description)
    render json: { prompt: prompt }
  rescue => e
    render json: { error: e.message }, status: 500
  end

  def create
    prompt = params[:prompt].to_s.strip
    return redirect_to new_image_path if prompt.blank?

    image_bytes = ImagenService.new.call(prompt)
    image_data  = Base64.strict_encode64(image_bytes)
    filename    = "#{prompt.parameterize.truncate(50, omission: '')}.png"

    respond_to do |format|
      format.html do
        @prompt     = prompt
        @image_data = image_data
        @filename   = filename
        render :new
      end
      format.json { render json: { image_data: image_data, filename: filename } }
    end
  rescue RuntimeError => e
    respond_to do |format|
      format.html do
        flash.now[:error] = "Image generation failed: #{e.message}"
        render :new
      end
      format.json { render json: { error: e.message }, status: 500 }
    end
  end
end
