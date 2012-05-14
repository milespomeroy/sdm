# local
require File.expand_path('../sdm/color', __FILE__)
require File.expand_path('../sdm/config', __FILE__)
require File.expand_path('../sdm/dir', __FILE__)
require File.expand_path('../trollop', __FILE__)

module Sdm

  SUB_COMMANDS = %w(st status envs migrate exec new drop)
  SCHEMA_VERSIONS = "schema-versions"

  class Start

    def initialize
    end

    def environments
      envs = Dir.entries(Sdm::SCHEMA_VERSIONS).delete_if do |f|
        (f =~ /properties/) == nil || f == "base-db.properties"
      end

      envs.each { |x| x.gsub!(/\.properties/, '') }

      puts "Environments to choose from:"
      envs.each { |x| puts "  " + x }
    end

    def mvn(task, opts)
      env = ARGV.shift
      properties_file = "#{Sdm::SCHEMA_VERSIONS}/#{env}.properties"

      unless File.exists?(properties_file)
        puts "Bad environment given.".red
        environments
        exit 1
      end

      config = parseconf("#{Sdm::SCHEMA_VERSIONS}/base-db.properties")
      sconfig = parseconf(properties_file)
      config.merge!(sconfig)
      schema = config['owningSchema']
      database = config['database']
      password = `pw get #{schema} #{database}`.chomp!


      cmd = "mvn -q " +
        "-Ddb.configurationFile=#{env}.properties " +
        "-Doracle.net.tns_admin=$TNS_ADMIN "

      # use specific schema or all specified in properties file
      if s = opts[:schema]
        cmd += "-Dschemas=#{s} "
        cmd += "-D#{s}.password=#{password} "
        if tv = opts[:target]
          cmd += "-D#{s}.targetVersion=#{tv} "
        end
      else
        config["schemas"].split(",").each do |s| 
          s.strip!
          cmd += "-D#{s}.password=#{password} "
        end
      end

      cmd += "stack-db:#{task}"

      system cmd
    end

    def new(opts)
      s = opts[:schema]
      cmd = "mvn -q " +
        "-Ddb.configurationFile=pom.properties " + # must define one
        "-Dschemas=#{s} " +
        "-D#{s}.password=blah " + # hangs if none is given
        "-Ddescription=\"#{opts[:name]}\" " +
        "stack-db:new"

      system cmd
    end

    def run
      unless Dir.chdir_to_parent_containing(Sdm::SCHEMA_VERSIONS)
        puts "ERROR: ".red +
          "Not a db migrator directory " +
          "(nor any of its parent directories)"
        exit 1
      end

      global_opts = Trollop::options do
        banner "Stack DB Migrator Helper"
        banner ""
        banner "Wraps the mvn commands for the stack db migrator"
        banner "to make it easier to use."
        banner ""
        version "0.1"
        opt :dry_run, "Don't actually do anything", :short => "-n"
        stop_on Sdm::SUB_COMMANDS
      end
      
      cmd = ARGV.shift # get the subcommand
      case cmd
        when "status", "st"
          opts = Trollop::options do
            banner "status: mvn stack-db:status".green
            banner ""
            opt :schema, "Specify schema. Default is read from schemas property.",
              :short => "-s", :type => :string
          end
          mvn("status", opts)
        when "migrate"
          opts = Trollop::options do
            banner "migrate: mvn stack-db:migrate".green
            banner ""
            opt :schema, "Specify schema. Default is read from schemas property.",
              :short => "-s", :type => :string
            opt :target, "Target version. Requires schema.", 
              :short => "-t", :type => :int
          end
          if opts[:target] && !opts[:schema]
            Trollop::die :schema, "required when target specified"
          end
          mvn("migrate", opts)
        when "new"
          opts = Trollop::options do
            banner "new: mvn stack-db:new".green
            banner <<-EOS
Create a new migration file.

EOS
            opt :schema, "Specify schema. Required.",
              :short => "-s", :type => :string, :required => true
            opt :name, "Name of new script. Required",
              :short => "-n", :type => :string, :required => true
          end
          new(opts)
        when "envs"
          environments
        else
          Trollop::die "unknown subcommand #{cmd.inspect}"
      end
      
    end

  end
end
