#!/usr/bin/env rake
# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

# fixes a bug with concurrent-ruby & rails < 7, concurrent-ruby does not
# require logger anymore, but rails does not require it either
require 'logger'

require File.expand_path('../config/application', __FILE__)

RedmineApp::Application.load_tasks
