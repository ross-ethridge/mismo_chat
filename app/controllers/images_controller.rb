class ImagesController < ApplicationController
  def new
  end

  def create
    prompt = params[:prompt].to_s.strip
    return redirect_to new_image_path if prompt.blank?

    image_bytes = ImagenService.new.call(prompt)

    @prompt = prompt
    @image_data = Base64.strict_encode64(image_bytes)
    @filename = "#{prompt.parameterize.truncate(50, omission: '')}.png"
    render :new
  rescue RuntimeError => e
    flash.now[:error] = "Image generation failed: #{e.message}"
    render :new
  end
end
