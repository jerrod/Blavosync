require 'blavosync/lib/ey_logger'
require 'blavosync/lib/ey_logger_hooks'
require 'blavosync/recipes/util'
require 'blavosync/recipes/local'
require 'blavosync/recipes/database'
require 'blavosync/recipes/content_tar'
require 'blavosync/recipes/content_rsync'
 
Capistrano::Configuration.instance(:must_exist).load do
  
  default_run_options[:pty] = true if respond_to?(:default_run_options)
  set :keep_releases, 3
  set :runner, defer { user }
  
end
