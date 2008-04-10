#!/usr/bin/ruby

require "rubygems"
require "rtask"
require "optparse"

$task = RTask.new

OptionParser.new(nil, 18) do |opt|
  opt.on("-r", "--release", "Release the packages") do
    puts "Release"
    $task.real_release
    exit
  end

  opt.on("-p", "--package", "Create gem and tgz packages") do
    puts "Create gem and tgz packages"
    $task.real_gem
    $task.real_tgz
  end

  opt.on("-h", "--help", "Show this message") do
    puts opt.help
    exit
  end

  opt.parse!(ARGV)
end
