# Yehuda Katz's writeup on using Gem Bundler today
#   http://yehudakatz.com/2009/11/03/using-the-new-gem-bundler-today/
# Nick Quaranto's post, 'Gem Bundler is the Future'
#   http://litanyagainstfear.com/blog/2009/10/14/gem-bundler-is-the-future/
# Thanks to Tom Ward for his writeup, 'A rails template for gem bundler'
#   http://tomafro.net/2009/11/a-rails-template-for-gem-bundler

# First thing's first, vendor the Gem Bundler gem (which itself can't 
# be bundle). 
# Install via GitHub
#   http://github.com/wycats/bundler

# note that the default bundle path is `vendor/gems` which is an overloaded 
# directory for Rails right now, so we'll install to `vendor/bundler_gems`.
# In Rails 3, we'll use `vendor/gems`
bundle_path = 'vendor/bundler_gems'

inside bundle_path do  
  run 'git init'
  run 'git pull --depth 1 git://github.com/wycats/bundler.git' 
  run 'rm -rf .git .gitignore'
end

# script to run the vendored `gem bundle`
file 'script/bundle', %{
#!/usr/bin/env ruby
$LOAD_PATH.unshift File.expand_path(File.join(File.dirname(__FILE__), "..", "#{bundle_path}/lib"))
require 'rubygems'
require 'rubygems/command'
require 'bundler'
require 'bundler/commands/bundle_command'
Gem::Commands::BundleCommand.new.invoke(*ARGV)
}.strip
run 'chmod +x script/bundle'

# Create Gem Bundler's Gemfile
file 'Gemfile', %{
clear_sources
source 'http://gemcutter.org'

disable_system_gems

bundle_path '#{bundle_path}'

gem 'rails', '#{Rails::VERSION::STRING}'
}.strip

# Ignore files under the bundle_path that can be regenerated from the 
# git repository
append_file '.gitignore', %{
gems/*
!gems/cache
!gems/bundler}

# Run `script/bundle` to actually grab and bundle our gems
run 'script/bundle'

# Ensure the bundler environment is loaded
append_file '/config/preinitializer.rb', %{
require File.expand_path(File.join(File.dirname(__FILE__), "..", "#{bundle_path}", "environment"))
}

gsub_file 'config/environment.rb', "require File.join(File.dirname(__FILE__), 'boot')", %{
require File.join(File.dirname(__FILE__), 'boot')

# Hijack rails initializer to load the bundler gem environment before loading the rails environment.

Rails::Initializer.mOdule_eval do
  alias load_environment_without_bundler load_environment
  
  def load_environment
    Bundler.require_env configuration.environment
    load_environment_without_bundler
  end
end
}