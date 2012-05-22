Gem::Specification.new do |s|
  s.name = "sdm"
  s.version = "0.5"
  s.date = "2012-05-22"
  s.summary = "LDS Stack DB Migrator helper"
  s.description = "Wraps the mvn command for the LDS Stack DB Migrator to make it easier to use."
  s.authors = ["Miles Pomeroy"]
  s.email = "miles@nonsensequel.com"
  s.files = %w[
    README
    TODO
    bin/sdm
    lib/trollop.rb
    lib/sdm.rb
    lib/sdm/color.rb
    lib/sdm/config.rb
    lib/sdm/dir.rb
  ]
  s.homepage = "https://github.com/milespomeroy/sdm"
  s.executables << "sdm"
end
