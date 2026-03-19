module ApplicationHelper
  def render_markdown(text)
    renderer = Redcarpet::Render::HTML.new(
      filter_html:     false,
      hard_wrap:       true,
      link_attributes: { target: "_blank", rel: "noopener noreferrer" }
    )
    markdown = Redcarpet::Markdown.new(renderer,
      fenced_code_blocks: true,
      tables:             true,
      autolink:           true,
      strikethrough:      true,
      no_intra_emphasis:  true,
      highlight:          true,
      superscript:        true
    )
    raw markdown.render(text.to_s)
  end
end
