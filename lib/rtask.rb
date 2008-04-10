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
  VERSION = "1"

  attr_reader :project, :package, :version

  def initialize(config={:use => :all})
    @rubyforge = ::RubyForge.new
    @user = @rubyforge.userconfig
    @gemify = Gemify.new.instance_eval{@settings}
    @project = @gemify[:rubyforge_project]
    @package = @gemify[:name]
    @version = @gemify[:version]
    if config.has_key?(:use)
      list = config[:use]
      list -= config[:exclude] if config[:exclude]
      use(*config[:use])
    end
    yield self if block_given?
  end

  # Specifies to use tasks.
  def use(*names)
    if names[0] == :all
      names = [:clean, :rdoc, :publish, :release, :gem, :tgz]
    end
    names.each do |name|
      send(name.to_sym)
    end
  end

  # Task for cleaning.
  def clean
    require 'rake/clean'
    CLEAN.include ['**/.*.sw?', '*.gem', '*.tgz', '.config', '**/.DS_Store']
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
    desc "Upload API documentation"
    task :publish => [:rdoc] do
      pub = Rake::RubyForgePublisher.new(@project, @user["username"])
      pub.upload
    end
  end

  # Task for release the package.
  def release
    desc 'Release new gem version'
    task :release do
      filename = "#{@package}-#{@version}"
      gem = filename + ".gem"
      tgz = filename + ".tgz"
      if File.exist?(gem) and File.exist?(tgz)
        @rubyforge.add_release @project, @package, @version, [gem, tgz]
        puts "Released #{gem} and #{tgz}"
      else
        puts "Please make gem and tgz files first: rake gem tgz"
        exit
      end
    end
  end

  # Task for creating gem.
  def gem
    desc "Create the gem package"
    task :gem do
      sh "gemify -I"
    end
  end

  # Task for creating tgz.
  def tgz
    desc "Create the tgz package"
    task :tgz do
      tgz = "#{@package}-#{@version}.tgz"
      sh "tar -T Manifest.txt -c -z -f #{tgz}"
    end
  end
end
