# local
require File.expand_path('../sdm/color', __FILE__)
require File.expand_path('../sdm/config', __FILE__)
require File.expand_path('../sdm/dir', __FILE__)
require File.expand_path('../trollop', __FILE__)

module Sdm

  SUB_COMMANDS = %w(st status envs migrate exec execute x new drop mi)
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
        Trollop::die "Bad environment given"
      end

      config = parseconf("#{Sdm::SCHEMA_VERSIONS}/base-db.properties")
      config.merge!(parseconf(properties_file))
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

      if task == "execute"
        script = ARGV.shift
        cmd += "-Ddb.scriptToExecute=#{script} "
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

      global = Trollop::Parser.new do
        banner "Stack DB Migrator Helper".green
        banner ""
        banner <<-EOS
Wraps the mvn command for the [LDS Stack DB Migrator][1] to make it easier to use.

[1]: http://code.lds.org/maven-sites/stack/module.html?module=db-migrator

Commands:

    envs              Show available environments to run migrations on.
    status    st      Display status of database. See pending migrations.
    migrate   mi      Apply scripts in queue to bring database to target.
    execute   exec x  Run specified script ad hoc. Without logging.
    new               Create a new blank script with timestamp in name.
    drop              Delete all objects in the database.

See `sdm <command> -h` to get additional help and usage on a specific command.

Global Options:
EOS
        banner ""
        version "0.5 Beta"
        stop_on Sdm::SUB_COMMANDS
      end

      global_opts = Trollop::with_standard_exception_handling global do
        o = global.parse ARGV
        raise Trollop::HelpNeeded if ARGV.empty?
        o
      end
      
      cmd = ARGV.shift # get the subcommand
      case cmd
        when "status", "st"
          opts = Trollop::options do
            banner "status: mvn stack-db:status".green
            banner ""
            banner <<-EOS
usage: sdm status ENV [-s SCHEMA]

Check the status of a database environment. Returns status of each schema listed in the 'schemas' attribute of the properties file for the environment, unless a schema is specified with the command.

Example: sdm status stg -s DEFAULT
EOS
            banner ""
            opt :schema, "Specify schema. Default is read from schemas property.",
              :short => "-s", :type => :string
          end
          mvn("status", opts)
        when "migrate", "mi"
          opts = Trollop::options do
            banner "migrate: mvn stack-db:migrate".green
            banner ""
            banner <<-EOS
usage: sdm migrate ENV [-s SCHEMA] [-t VERSION_NUMBER]

Apply scripts found in the schemas' queues to bring a database to the target version number.

Example: sdm migrate stg -s DEFAULT -t 201205151242
EOS
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
        when "execute", "exec", "x"
          opts = Trollop::options do
            banner "execute: mvn stack-db:execute".green
            banner ""
            banner <<-EOS
usage: sdm execute ENV -s SCHEMA SCRIPT

Run a specified SQL script. Execution is not logged. Script must exist in the schema directory specified.

Example: sdm execute stg -s DEFAULT test.sql
EOS
            banner ""
            opt :schema, "Specify schema. Required.",
              :short => "-s", :type => :string, :required => true
          end
          mvn("execute", opts)
        when "drop"
          opts = Trollop::options do
            banner "drop: mvn stack-db:drop".green
            banner ""
            banner <<-EOS
usage: sdm drop ENV [-s SCHEMA]

Delete all objects from the database. Will run on all schemas in the properties file unless a SCHEMA is specified.  Uses the db.dropScript property to identify what script to run. If that is not set it uses the built-in drop script.

Example: sdm drop stg -s DEFAULT
EOS
            banner ""
            opt :schema, "Specify schema.",
              :short => "-s", :type => :string
          end
          mvn("drop", opts)
        when "new"
          opts = Trollop::options do
            banner "new: mvn stack-db:new".green
            banner ""
            banner <<-EOS
usage: sdm new -s SCHEMA -n NAME

Create a new migration file in a schema. The current timestamp is prefixed to the name of the file.

Example: sdm new -s DEFAULT -n "update a table"

EOS
            banner ""
            opt :schema, "Specify schema. Required.",
              :short => "-s", :type => :string, :required => true
            opt :name, "Name of new script. Required.",
              :short => "-n", :type => :string, :required => true
          end
          new(opts)
        when "envs"
          opts = Trollop::options do
            banner "envs: List available environments.".green
            banner ""
            banner <<-EOS
usage: sdm envs

Lists names of environments that can be used in other commands.  Each environments corresponds to a properties file in the schema-versions directory.

Example: sdm envs
EOS
            banner ""
          end
          environments
        else
          puts "Error: ".red + "Unknown command #{cmd.inspect}."
          puts "See 'sdm --help'."
          exit 1
      end
      
    end

  end
end
