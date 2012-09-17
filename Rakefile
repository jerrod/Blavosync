require 'rubygems'
require 'rake'

# begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "blavosync"
    gem.summary = %Q{Sync a remote db and rsync content to your development environment.}
    gem.description = %Q{Sync a remote db and rsync content to your development environment.  Useful for small teams and developers who are not able to do this manually.}
    gem.email = "jerrodblavos@mac.com"
    gem.homepage = "http://github.com/indierockmedia/Blavosync"
    gem.authors = ["jayronc"]
    gem.has_rdoc = false

  end
  Jeweler::GemcutterTasks.new
# rescue LoadError
#   puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
# end


require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test' << 'recipes'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |test|
    test.libs << 'test' << 'recipes'
    test.pattern = 'test/**/test_*.rb'
    test.verbose = true
  end
rescue LoadError
  task :rcov do
    abort "RCov is not available. In order to run rcov, you must: sudo gem install spicycode-rcov"
  end
end

task :default => :test

require 'rdoc/task'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "blavosync #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
