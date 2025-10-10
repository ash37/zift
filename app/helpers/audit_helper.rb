module AuditHelper
  def gender_badge(user)
    gender = user.gender.to_s.downcase

    icon, colors = case gender
    when "female", "woman", "f"
                     [ female_svg, "bg-pink-100 text-pink-500" ]
    when "male", "man", "m"
                     [ male_svg, "bg-blue-100 text-blue-500" ]
    when "non-binary", "nb", "nonbinary", "non binary"
                     [ other_svg, "bg-violet-100 text-violet-500" ]
    else
                     [ other_svg, "bg-yellow-100 text-yellow-500" ]
    end

    age_text = calculate_age(user.date_of_birth)
    content_tag :span, class: "inline-flex items-center gap-1 rounded-3xl px-2 py-1 #{colors}" do
      icon.html_safe +
        content_tag(:span, age_text, class: "text-xs font-medium")
    end
  end

  private

  def female_svg
    <<~HTML
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="h-4 w-4">
        <path fill-rule="evenodd" clip-rule="evenodd" d="M20 9C20 13.0803 16.9453 16.4471 12.9981 16.9383C12.9994 16.9587 13 16.9793 13 17V19H14C14.5523 19 15 19.4477 15 20C15 20.5523 14.5523 21 14 21H13V22C13 22.5523 12.5523 23 12 23C11.4477 23 11 22.5523 11 22V21H10C9.44772 21 9 20.5523 9 20C9 19.4477 9.44772 19 10 19H11V17C11 16.9793 11.0006 16.9587 11.0019 16.9383C7.05466 16.4471 4 13.0803 4 9C4 4.58172 7.58172 1 12 1C16.4183 1 20 4.58172 20 9ZM6.00365 9C6.00365 12.3117 8.68831 14.9963 12 14.9963C15.3117 14.9963 17.9963 12.3117 17.9963 9C17.9963 5.68831 15.3117 3.00365 12 3.00365C8.68831 3.00365 6.00365 5.68831 6.00365 9Z" />
      </svg>
    HTML
  end

  def male_svg
    <<~HTML
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor" class="h-4 w-4">
        <path fill-rule="evenodd" clip-rule="evenodd" d="M15 3C15 2.44772 15.4477 2 16 2H20C21.1046 2 22 2.89543 22 4V8C22 8.55229 21.5523 9 21 9C20.4477 9 20 8.55228 20 8V5.41288L15.4671 9.94579C15.4171 9.99582 15.363 10.0394 15.3061 10.0767C16.3674 11.4342 17 13.1432 17 15C17 19.4183 13.4183 23 9 23C4.58172 23 1 19.4183 1 15C1 10.5817 4.58172 7 9 7C10.8559 7 12.5642 7.63197 13.9214 8.69246C13.9587 8.63539 14.0024 8.58128 14.0525 8.53118L18.5836 4H16C15.4477 4 15 3.55228 15 3ZM9 20.9963C5.68831 20.9963 3.00365 18.3117 3.00365 15C3.00365 11.6883 5.68831 9.00365 9 9.00365C12.3117 9.00365 14.9963 11.6883 14.9963 15C14.9963 18.3117 12.3117 20.9963 9 20.9963Z" />
      </svg>
    HTML
  end

  def other_svg
    <<~HTML
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" class="h-4 w-4">
        <path d="M21 12C21 16.9706 16.9706 21 12 21C7.02944 21 3 16.9706 3 12C3 7.02944 7.02944 3 12 3C16.9706 3 21 7.02944 21 12Z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" stroke-dasharray="4 4" />
      </svg>
    HTML
  end

  def calculate_age(dob)
    return '—' unless dob.present?
    today = Date.current
    years = today.year - dob.year
    years -= 1 if dob.to_date.change(year: today.year) > today
    years.positive? ? "#{years} yrs" : '—'
  rescue
    '—'
  end
end
