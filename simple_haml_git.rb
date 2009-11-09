# newsimplegit.rb
#
# Creates a new rails application using git for version control and 
# haml for view templates
# Initializes the git based on the sake task published on
# http://gist.github.com/6750
# task 'git:rails:new_app', :needs => [ 'rails:rm_tmp_dirs', 'git:hold_empty_dirs' ]

gem 'haml'

file 'vendor/plugins/haml/init.rb', <<-CODE
begin
  require File.join(File.dirname(__FILE__), 'lib', 'haml') # From here
rescue LoadError
  require 'haml' # From gem
end

# Load Haml and Sass
Haml.init_rails(binding)
CODE

# rails:rm_tmp_dirs
["./tmp/pids", "./tmp/sessions", "./tmp/sockets", "./tmp/cache"].each do |f|
  run("rmdir ./#{f}")
end

# git:hold_empty_dirs
run("find . \\( -type d -empty \\) -and \\( -not -regex ./\\.git.* \\) -exec touch {}/.gitignore \\;")

# git:rails:new_app
git :init

file '.gitignore', <<-CODE
.DS_Store
*~
log/*.log
db/*.db
db/*.sqlite3
tmp/**/*
CODE

run "cp config/database.yml config/database.yml.sample"

git :add => "."

git :commit => "-a -m 'Setting up a new rails app. Copy config/database.yml.sample to config/database.yml and customize.'"
