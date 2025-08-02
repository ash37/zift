module RostersHelper
  def format_shift_time(time)
    return "" unless time

    hour = time.strftime("%-l")
    min  = time.strftime("%M")
    mer  = time.strftime("%P")
    min == "00" ? "#{hour}#{mer}" : "#{hour}:#{min}#{mer}"
  end
end
