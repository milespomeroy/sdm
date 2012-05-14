class Dir

  class << self
    def chdir_to_parent_containing(file)

      dir = Dir.pwd.split("/")

      (dir.size - 1).times do |x|
        d = dir.join("/")

        if Dir.entries(d).include?(file)
          Dir.chdir(d)
          return true
        end

        dir.pop
      end

      return false

    end
  end

end
