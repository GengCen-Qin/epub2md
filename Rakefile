require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

namespace :epub2md do
  desc "Install dependencies"
  task :install do
    sh "bundle install"
  end

  desc "Run tests"
  task :test => :spec

  desc "Build gem"
  task :build do
    sh "gem build epub2md.gemspec"
  end

  desc "Install gem locally"
  task :install_gem => :build do
    gem_file = Dir.glob("*.gem").first
    sh "gem install #{gem_file}" if gem_file
  end
end