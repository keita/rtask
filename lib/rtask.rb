require 'rake'
require 'rubyforge'
require 'gemify'

# == Usage
# First, you setup gemify.
#   % gemify
#
# Second, add RTask in your Rakefile:
#   require 'rubygems'
#   require 'rtask'
#   RTask.new
#
# Result:
#   % rake -T
#   rake clean         # Remove any temporary products.
#   rake clobber       # Remove any generated file.
#   rake clobber_rdoc  # Remove rdoc products
#   rake gem           # Create the gem package
#   rake publish       # Upload API documentation
#   rake rdoc          # Build the rdoc HTML Files
#   rake release       # Release new gem version
#   rake rerdoc        # Force a rebuild of the RDOC files
#   rake tgz           # Create the tgz package
#
class RTask
  VERSION = "009"
  MESSAGE = Hash.new

  attr_reader :project, :package, :version

  def initialize(config={:use => :all})
    @rubyforge = ::RubyForge.new
    @user = @rubyforge.userconfig
    @gemify = Gemify.new.instance_eval{@settings}
    @project = @gemify[:rubyforge_project]
    @package = @gemify[:name]
    @version = @gemify[:version]
    @lib_version = config[:version]
    if config.has_key?(:use)
      list = config[:use]
      list -= config[:exclude] if config[:exclude]
      use(*config[:use])
    end
    yield self if block_given?
  end

  # define task
  def self.define_task(description, rule)
    name = rule
    if rule.kind_of?(Hash)
      name = rule.keys.first
    end

    MESSAGE[name] = description

    define_method("register_task_#{name}") do |rtask|
      desc description if description
      task(rule){ rtask.send name if rtask.respond_to?(name) }
    end
  end

  # Specifies to use tasks
  def use(*names)
    if names[0] == :all
      names = [:clean, :rdoc, :publish, :release, :packages]
    end
    names.each do |name|
      register = "register_task_#{name}"
      case name
      when :clean, :rdoc
        send(name)
      when :packages
        send(register, self)
        send("register_task_gem", self)
        send("register_task_tgz", self)
        send("register_task_zip", self)
      else
        send(register, self)
      end
    end
  end

  # Task for cleaning.
  def clean
    require 'rake/clean'
    CLEAN.include ['html', '*.gem', '*.tgz', '*.zip', '.config', '**/.DS_Store']
  end

  # Task for generating documents using rdoc.
  def rdoc
    require 'rake/rdoctask'
    Rake::RDocTask.new do |doc|
      doc.title = "#{@package}-#{@version} documentation"
      doc.main = "README.txt"
      doc.rdoc_files.include("{README,History,License}.txt", "lib/**/*.rb")
      doc.options << "--line-numbers" << "--inline-source" << "-c UTF-8"
      yield doc if block_given?
    end
  end

  # Task for uploading API documentation.
  def publish
    require 'rake/contrib/rubyforgepublisher'
    pub = Rake::RubyForgePublisher.new(@project, @user["username"])
    pub.upload
  end

  define_task "Upload API documentation", :publish => [:rdoc]

  # Task for release the package.
  def release
    if @lib_version and @version.to_s != @lib_version.to_s
      puts "Version confilict between the library and in .gemified"
      puts "library: " + @lib_version.to_s
      puts "Gemify : " + @version.to_s
      exit
    end
    filename = "#{@package}-#{@version}"
    gem = filename + ".gem"
    tgz = filename + ".tgz"
    zip = filename + ".zip"
    if File.exist?(gem) and File.exist?(tgz)
      @rubyforge.add_release @project, @package, @version, gem, tgz, zip
      puts "Released #{gem}, #{tgz}, and #{zip}"
    else
      puts "Please make gem and tgz files first: rake gem tgz"
      exit
    end
  end

  define_task 'Release new gem', :release => [:packages]

  # Task for creating packages
  define_task "Create packages", :packages => [:gem, :tgz, :zip]

  # Task for creating gem
  def gem
    sh "gemify -I"
  end

  define_task "Create the gem package", :gem

  # Task for creating tgz
  def tgz
    tgz = "#{@package}-#{@version}.tgz"
    sh "tar -T Manifest.txt -c -z -f #{tgz}"
  end

  define_task "Create the tgz package", :tgz

  # Task for creating zip
  def zip
    require "zip/zipfilesystem"
    filename = "#{@package}-#{@version}.zip"
    rm filename if File.exist?(filename)
    Zip::ZipFile.open(filename, Zip::ZipFile::CREATE) do |zip|
      manifest.each do |file|
        zip.file.open(File.join("#{package}-#{@version}", file), "w") do |out|
          out.write(File.open(file).read)
        end
      end
    end
  end

  define_task "Create the zip package", :zip

  private

  def manifest
    manifest = Dir.glob("*Manifest*", File::FNM_CASEFOLD).first
    unless manifest
      puts "Please make manifest"
      exit
    end
    File.read(manifest).split("\n")
  end
end
