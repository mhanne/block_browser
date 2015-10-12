#!/usr/bin/env rake
# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require File.expand_path('../config/application', __FILE__)

BlockBrowser::Application.load_tasks

namespace :spec do
  desc "Clean all temporary / cached data used by the specs"
  task :clean_tmp do
    FileUtils.rm(File.join(Rails.root, "tmp/spec.db"))
    FileUtils.rm(File.join(Rails.root, "spec/data/base.db"))
  end
end

task :doc do
  `rm -rf doc`
  system("yard")
end
