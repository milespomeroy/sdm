# based from http://www.erickcantwell.com/code/config.rb
def parseconf(conf_file)
  props = {}

  unless File.exists?(conf_file)
    raise "Properties file not found: #{conf_file}."
  end

  IO.foreach(conf_file) do |line|
    next if line.match(/^#/)
    next if line.match(/^$/)

    if line.match(/=/)
      eq = line.index("=")

      key = line[0..eq-1].strip
      value = line[eq+1..-1].strip

      props[key] = value
    end
  end

  return props
end

