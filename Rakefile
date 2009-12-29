require 'rubygems'
require 'hoe'
require './lib/blavosync'

Hoe.spec('blavosync') do |p|
  p.author = 'Jerrod Blavos'
  p.email = 'jerrodblavos@mac.com'
  p.summary = %Q{Sync a remote db and rsync content to your development environment.}
  p.description = %Q{Sync a remote db and rsync content to your development environment.  Useful for small teams and developers who are not able to do this manually.}
  p.url = "http://github.com/indierockmedia/Blavosync"
  p.changes = p.paragraphs_of('History.txt', 0..1).join("\n\n")
  p.extra_deps << ['capistrano', '>= 2.2.0']
  p.version = Blavosync::VERSION
end

desc "Open an irb session preloaded with this library"
task :console do
  sh "irb -rubygems -r ./lib/blavosync.rb"
end

task :coverage do
  system("rm -fr coverage")
  system("rcov test/test_*.rb")
  system("open coverage/index.html")
end

desc "Upload site to Rubyforge"
task :site do
end

desc 'Install the package as a gem.'
task :install_gem_no_doc => [:clean, :package] do
  sh "#{'sudo ' unless Hoe::WINDOZE}gem install --local --no-rdoc --no-ri pkg/*.gem"
end
