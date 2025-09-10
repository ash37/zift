class AgreementPdf
  def self.render(agreement, acceptance, extra: {})
    require "prawn"
    begin
      require "prawn/table"
    rescue LoadError
      # Table rendering will be skipped if prawn-table is unavailable
    end
    Prawn::Document.new(page_size: "A4") do |pdf|
      # Try to use a Unicode TTF to avoid encoding issues with smart quotes/arrows/etc.
      unicode_candidates = [
        Rails.root.join("app/assets/fonts/NotoSans-Regular.ttf"),
        Rails.root.join("app/assets/fonts/DejaVuSans.ttf")
      ]
      unicode_path = unicode_candidates.find { |p| File.exist?(p) }
      if unicode_path
        pdf.font_families.update(
          "Unicode" => {
            normal: unicode_path.to_s,
            bold: unicode_path.to_s,
            italic: unicode_path.to_s,
            bold_italic: unicode_path.to_s
          }
        )
        pdf.font("Unicode")
      end
      pdf.text agreement.title, size: 20, style: :bold, align: :center
      pdf.move_down 10
      pdf.text "Version: #{agreement.version}", size: 10, align: :center
      pdf.move_down 20

      rendered = AgreementRenderer.render(agreement, user: acceptance.user, acceptance: acceptance, extra: extra)
      render_html_with_tables(pdf, rendered)

      pdf.move_down 30
      pdf.stroke_horizontal_rule
      pdf.move_down 15
      pdf.text "Signed by:", style: :bold
      # Use a cursive font if available, otherwise fall back to italic
      cursive_ttf = Rails.root.join("app/assets/fonts/MrDafoe-Regular.ttf")
      if File.exist?(cursive_ttf)
        pdf.font_families.update("MrDafoe" => { normal: cursive_ttf.to_s })
        pdf.font("MrDafoe")
        pdf.text ensure_pdf_compatible(acceptance.signed_name), size: 28
        pdf.font("Helvetica")
      else
        pdf.text ensure_pdf_compatible(acceptance.signed_name), size: 22, style: :italic
      end
      pdf.move_down 10
      pdf.text "Date: #{acceptance.signed_at.strftime('%-d %b %Y %H:%M %Z')}"
      pdf.text "IP: #{acceptance.ip_address}"
      pdf.text "User-Agent: #{acceptance.user_agent}"
      pdf.move_down 10
      pdf.text "Content Hash: #{acceptance.content_hash}", size: 8
    end.render
  end

  # Render HTML with very simple support for <table> segments via prawn-table.
  def self.render_html_with_tables(pdf, html)
    parts = []
    pos = 0
    html.to_s.scan(/<table[\s\S]*?<\/table>/i) do |tbl|
      m = Regexp.last_match
      pre = html[pos...m.begin(0)]
      parts << [ :text, pre ] if pre.present?
      parts << [ :table, tbl ]
      pos = m.end(0)
    end
    parts << [ :text, html[pos..-1] ] if pos < html.to_s.length

    parts.each do |kind, content|
      case kind
      when :text
        formatted = inline_text_from_html(content)
        formatted = ensure_pdf_compatible(formatted)
        next if formatted.strip.empty?
        pdf.text formatted, size: 11, leading: 2, inline_format: true
        pdf.move_down 6
      when :table
        data = parse_html_table(content)
        next if data.empty?
        if defined?(Prawn::Table)
          header_flag = table_has_header?(content)
          pdf.table(data, header: header_flag, cell_style: { size: 10, inline_format: false }) do
            row(0).font_style = :bold if header_flag
            self.position = :left
            self.width = pdf.bounds.width
          end
          pdf.move_down 10
        else
          # Fallback: render as plain text rows
          data.each { |row| pdf.text ensure_pdf_compatible(row.join(" | ")), size: 10 }
          pdf.move_down 10
        end
      end
    end
  end

  def self.inline_text_from_html(html)
    (html || "")
      .gsub(/<(\/?)strong>/i, '<\1b>')
      .gsub(/<(\/?)em>/i, '<\1i>')
      .gsub(/<br\s*\/?\s*>/i, "\n")
      .gsub(/<\/(p|li|h[1-4])>/i, "\n\n")
      .gsub(/<[^>]+>/, "")
  end

  def self.parse_html_table(tbl_html)
    rows = []
    return rows if tbl_html.blank?
    # Extract header cells if present
    thead = tbl_html[/<thead[\s\S]*?<\/thead>/i]
    if thead
      rows << extract_row_cells(thead, "th") if extract_row_cells(thead, "th").any?
    end
    # Extract body rows
    body_html = tbl_html[/<tbody[\s\S]*?<\/tbody>/i] || tbl_html
    body_html.scan(/<tr[\s\S]*?<\/tr>/i) do |tr|
      cells = extract_row_cells(tr, "td")
      cells = extract_row_cells(tr, "th") if cells.empty? # handle tables without proper tbody/thead
      rows << cells unless cells.empty?
    end
    rows
  end

  def self.extract_row_cells(tr_html, cell_tag)
    cells = []
    tr_html.to_s.scan(/<#{cell_tag}[^>]*>([\s\S]*?)<\/#{cell_tag}>/i) do |m|
      cell_html = m.first.to_s
      text = inline_text_from_html(cell_html).gsub(/\s+/, " ").strip
      text = ensure_pdf_compatible(text)
      cells << text
    end
    cells
  end

  def self.table_has_header?(tbl_html)
    !!(tbl_html =~ /<thead[\s\S]*?<\/thead>/i)
  end

  # Replace common non-Win1252 glyphs with ASCII equivalents when not using a Unicode font
  def self.ensure_pdf_compatible(str)
    s = (str || "").dup
    replacements = {
      "\u2018" => "'", # left single quote
      "\u2019" => "'", # right single quote
      "\u201C" => '"',  # left double quote
      "\u201D" => '"',  # right double quote
      "\u2013" => "-",  # en dash
      "\u2014" => "--", # em dash
      "\u2022" => "*",  # bullet
      "\u2026" => "...", # ellipsis
      "\u2192" => "->", # right arrow
      "\u00A0" => " "   # non-breaking space
    }
    s.gsub!(Regexp.union(replacements.keys), replacements)
    s
  end
end
