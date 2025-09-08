module AgreementsHelper
  def render_agreement_html(agreement, user:, acceptance: nil, location: nil)
    extra = {}
    extra[:location] = location if location
    rendered = AgreementRenderer.render(agreement, user: user, acceptance: acceptance, extra: extra)
    allowed_tags = %w[p br strong em b i u s del sub sup h1 h2 h3 h4 ul ol li blockquote a span table thead tbody tfoot tr th td]
    allowed_attrs = %w[href target rel class colspan rowspan]
    sanitize(rendered, tags: allowed_tags, attributes: allowed_attrs)
  end
end
