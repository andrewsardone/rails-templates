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

gem 'haml', '2.2.13'
gem 'clearance'
gem 'will_paginate'
gem 'resource_controller'
gem 'rspec-rails'

only :test do
  gem 'rspec'
  gem 'cucumber'
  gem 'webrat'
  gem 'factory_girl'
end
}.strip

# Ignore files under the bundle_path that can be regenerated from the 
# git repository
append_file '.gitignore', %{
#{bundle_path}/*
!#{bundle_path}/cache
!#{bundle_path}/bundler
}

# Run `script/bundle` to actually grab and bundle our gems
run 'script/bundle'

# Setup rspec and cucumber
run 'script/generate rspec'
run 'script/generate cucumber'

# Ensure the bundler environment is loaded
append_file '/config/preinitializer.rb', %{
require File.expand_path(File.join(File.dirname(__FILE__), "..", "#{bundle_path}", "environment"))
}

gsub_file 'config/environment.rb', "require File.join(File.dirname(__FILE__), 'boot')", %{
require File.join(File.dirname(__FILE__), 'boot')

# Hijack rails initializer to load the bundler gem environment before loading the rails environment.

Rails::Initializer.module_eval do
  alias load_environment_without_bundler load_environment
  
  def load_environment
    Bundler.require_env configuration.environment
    load_environment_without_bundler
  end
end
}

# Setup haml
file 'vendor/plugins/haml/init.rb', %{
begin
  require File.join(File.dirname(__FILE__), 'lib', 'haml') # From here
rescue LoadError
  require 'haml' # From gem
end

# Load Haml and Sass.
Haml.init_rails(binding)
}

# add the standard stuff to .gitignore
append_file '.gitignore', %{
.DS_Store
*~
log/*.log
tmp/**/*
log/*.pid
log/call_*
config/database.yml
db/*.sqlite3
db/*.bkp
db/*.bak
*.swp
webrat*.html
}

run "cp config/database.yml config/database.yml.sample"

# Delete unnecessary files
["./tmp/pids", "./tmp/sessions", "./tmp/sockets", "./tmp/cache"].each do |f|
  run "rmdir ./#{f}"
end
run "rm README"
run "rm public/index.html"
run "rm public/favicon.ico"

# git:hold_empty_dirs
run("find . \\( -type d -empty \\) -and \\( -not -regex ./\\.git.* \\) -exec touch {}/.gitignore \\;")

# Grab jQuery
run "curl -L http://jqueryjs.googlecode.com/files/jquery-1.3.2.min.js > public/javascripts/jquery.js"

# Create a project GNU screen configuration file
#   Enter into screen session via `screen -c .screenrc`
file '.screenrc', %{
# GNU screen configuration file for a Rails project

# Basic
defscrollback   10000
autodetach      on

# status
hardstatus alwayslastline "%{= kw}%{g}[ %{R}%H %{g}] %{Y} %{g}[%=%{ =kw}%{w}%-w%{Y}[%{W}%n-%t%{Y}]%{w}%+w%=%{g}][ %{w}%m-%d %{Y}%c %{g}]"

# add caption
caption splitonly "%{= kw}%?%-Lw%?%{kw}%n*%t%f %?(%u)%?%{= kw}%?%+Lw%?"

# xterm scrollback
termcapinfo xterm ti@:te@
startup_message	off

# Tell Screen to write its copy buffer to a temporary file (defaults to
# /tmp/screen-exchange), and then send that file to `pbcopy`.
# Bound the command to C-a b
# http://www.samsarin.com/blog/2007/03/11/gnu-screen-working-with-the-scrollback-buffer/
#
# NOTE: This is Mac OS X specific
bind b eval "writebuf" "exec sh -c 'pbcopy < /tmp/screen-exchange'"

# Start four named windows
#
#   - window 0: the RAILS_ROOT directory
#   - window 1: script/server
#   - window 2: script/console
#   - window 3: script/autospec
#
# Then, split the window horizontally with the RAILS_ROOT window on top and autospec
# running on the bottom
screen -t "src" 0

screen -t "server" 1
stuff "./script/server\\012"

screen -t "console" 2
stuff "./script/console\\012"

split

focus down

screen -t "autospec" 3
stuff "./script/autospec\\012"

focus top
select 0
}

git :init
git :add => '.'
git :commit => "-a -m 'Setting up a new rails app. Copy config/database.yml.sample to config/database.yml and customize.'"
