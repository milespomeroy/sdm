# Extend String to add color
class String
  def green
    "[32m" + self + "[0m"
  end
  def red
    "[31m" + self + "[0m"
  end
end


