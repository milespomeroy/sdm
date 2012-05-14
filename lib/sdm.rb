# local
require File.expand_path('../sdm/color', __FILE__)
require File.expand_path('../sdm/config', __FILE__)
require File.expand_path('../sdm/dir', __FILE__)
require File.expand_path('../trollop', __FILE__)

module Sdm

  SUB_COMMANDS = %w(status envs delete copy)
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
      else
        config["schemas"].split(",").each do |s| 
          s.strip!
          cmd += "-D#{s}.password=#{password} "
        end
      end

      cmd += "stack-db:#{task}"

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
      cmd_opts = case cmd
        when "status"
          opts = Trollop::options do
            banner "Run mvn stack-db:status"
            opt :schema, "Specify schema. Default is read from schemas property.",
              :short => "-s", :type => :string
          end
          mvn("status", opts)
        when "envs"
          environments
        when "delete" # parse delete options
          Trollop::options do
            banner "Delete thingy"
            opt :force, "Force deletion"
          end
        when "copy"  # parse copy options
          Trollop::options do
            opt :double, "Copy twice for safety's sake"
          end
        else
          Trollop::die "unknown subcommand #{cmd.inspect}"
        end
      
      #puts "Global options: #{global_opts.inspect}"
      #puts "Subcommand: #{cmd.inspect}"
      #puts "Subcommand options: #{cmd_opts.inspect}"
      #puts "Remaining arguments: #{ARGV.inspect}"
    end

  end
end
