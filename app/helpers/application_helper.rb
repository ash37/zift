module ApplicationHelper
  # Returns true if the start/end look like a full local day (12:00am → ~11:59:59pm)
  # based purely on the times (independent of any persisted all_day? flag).
  def all_day_range?(starts_at, ends_at)
    return false if starts_at.blank? || ends_at.blank?

    s = starts_at.in_time_zone(Time.zone)
    e = ends_at.in_time_zone(Time.zone)

    # must be the same local date
    return false unless s.to_date == e.to_date

    # exactly at local midnight for start
    starts_at_midnight = (s == s.beginning_of_day)

    # at end-of-day for finish; allow 23:59:59, 23:59:59.999999, or exactly end_of_day
    eod = e.end_of_day
    ends_at_eod = (e >= (eod - 1.second) && e <= eod)

    starts_at_midnight && ends_at_eod
  end

  # Formats the range as "ALLDAY" if the times indicate an all-day span; otherwise HH:MM - HH:MM
  def display_range_or_allday(starts_at, ends_at)
    if all_day_range?(starts_at, ends_at)
      "ALLDAY"
    else
      "#{format_shift_time(starts_at)} - #{format_shift_time(ends_at)}"
    end
  end
end
