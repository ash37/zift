class AgreementPdf
  def self.render(agreement, acceptance, extra: {})
    require "prawn"
    begin
      require "prawn/table"
    rescue LoadError
      # Table rendering will be skipped if prawn-table is unavailable
    end
    Prawn::Document.new(page_size: "A4") do |pdf|
      # Register fonts with proper bold support; fall back to Helvetica if bold not available
      register_fonts_with_bold(pdf)
      pdf.font(@@pdf_base_font || "Helvetica")
      pdf.text agreement.title, size: 20, style: :bold, align: :center
      pdf.move_down 4
      pdf.text "Version: #{agreement.version}", size: 10, align: :center
      pdf.move_down 6

      rendered = AgreementRenderer.render(agreement, user: acceptance.user, acceptance: acceptance, extra: extra)
      render_html_with_tables(pdf, rendered)

      pdf.move_down 10
      pdf.stroke_horizontal_rule
      pdf.move_down 6
      pdf.text "Signed by:", style: :bold
      # Use a cursive font if available, otherwise fall back to italic
      cursive_ttf = Rails.root.join("app/assets/fonts/MrDafoe-Regular.ttf")
      if File.exist?(cursive_ttf)
        pdf.font_families.update("MrDafoe" => { normal: cursive_ttf.to_s })
        pdf.font("MrDafoe")
        pdf.text ensure_pdf_compatible(acceptance.signed_name), size: 24
        pdf.font("Helvetica")
      else
        pdf.text ensure_pdf_compatible(acceptance.signed_name), size: 20, style: :italic
      end
      pdf.move_down 4
      # Use a monospace font for metadata
      begin
        pdf.font("Courier")
      rescue
        # Fall back if Courier unavailable (should exist in Prawn)
      end
      pdf.text "Date: #{acceptance.signed_at.strftime('%-d %b %Y %H:%M %Z')}", size: 10
      # Signed participant email immediately under the signed date
      participant_email = (extra[:location]&.email.presence if extra.is_a?(Hash)) || (acceptance.respond_to?(:email) ? acceptance.email : nil)
      participant_email = participant_email.presence || "N/A"
      pdf.text "Signed Participant Email: #{ensure_pdf_compatible(participant_email)}", size: 10
      
      pdf.text "IP: #{ensure_pdf_compatible(acceptance.ip_address)}", size: 10
      pdf.text "User-Agent: #{ensure_pdf_compatible(acceptance.user_agent)}", size: 10
      pdf.text "Content Hash: #{ensure_pdf_compatible(acceptance.content_hash)}", size: 9
      # Extra spacing before the created/sent details
      pdf.move_down 12

      # Additional details
      sent_at = acceptance.respond_to?(:emailed_at) ? acceptance.emailed_at : nil
      sent_at_str = sent_at.present? ? sent_at.strftime('%-d %b %Y %H:%M %Z') : "N/A"
      pdf.text "Agreement Created: #{sent_at_str}", size: 10
      pdf.text "Email: ak@qcare.au", size: 10
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
        # As tight as possible without overlapping; avoid extra gap after blocks
        pdf.text formatted, size: 11, leading: -1, inline_format: true
      when :table
        data = parse_html_table(content)
        next if data.empty?
        if defined?(Prawn::Table)
          header_flag = table_has_header?(content)
          pdf.table(data, header: header_flag, cell_style: { size: 10, inline_format: false, padding: [2,2,2,2] }) do
            row(0).font_style = :bold if header_flag
            self.position = :left
            self.width = pdf.bounds.width
          end
          pdf.move_down 4
        else
          # Fallback: render as plain text rows
          data.each { |row| pdf.text ensure_pdf_compatible(row.join(" | ")), size: 10 }
          pdf.move_down 4
        end
      end
    end
  end

  def self.inline_text_from_html(html)
    (html || "")
      .gsub(/<(\/?)strong>/i, '<\1b>')
      .gsub(/<(\/?)em>/i, '<\1i>')
      .gsub(/<br\s*\/?\s*>/i, "\n")
      .gsub(/<\/(p|li|h[1-4])>/i, "\n")
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

  # Try to register a font family with real bold support. Sets @@pdf_base_font accordingly.
  def self.register_fonts_with_bold(pdf)
    begin
      base_dir = Rails.root.join("app/assets/fonts")
      # Prefer Noto Sans if both regular and bold are available
      noto_regular = base_dir.join("NotoSans-Regular.ttf")
      noto_bold    = base_dir.join("NotoSans-Bold.ttf")
      if File.exist?(noto_regular) && File.exist?(noto_bold)
        pdf.font_families.update(
          "Unicode" => {
            normal: noto_regular.to_s,
            bold:   noto_bold.to_s,
            italic: noto_regular.to_s,
            bold_italic: noto_bold.to_s
          }
        )
        @@pdf_base_font = "Unicode"
        return
      end

      # Fallback to DejaVu if available
      deja_regular = base_dir.join("DejaVuSans.ttf")
      deja_bold    = base_dir.join("DejaVuSans-Bold.ttf")
      if File.exist?(deja_regular) && File.exist?(deja_bold)
        pdf.font_families.update(
          "Unicode" => {
            normal: deja_regular.to_s,
            bold:   deja_bold.to_s,
            italic: deja_regular.to_s,
            bold_italic: deja_bold.to_s
          }
        )
        @@pdf_base_font = "Unicode"
        return
      end
    rescue => _e
      # If anything fails, we will fall back to Helvetica below
    end
    @@pdf_base_font = "Helvetica"
  end
end
