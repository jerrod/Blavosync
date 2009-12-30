# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run the gemspec command
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{blavosync}
  s.version = "0.2.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["jayronc"]
  s.date = %q{2009-12-29}
  s.description = %q{Sync a remote db and rsync content to your development environment.  Useful for small teams and developers who are not able to do this manually.}
  s.email = %q{jerrodblavos@mac.com}
  s.extra_rdoc_files = [
    "LICENSE",
     "README.markdown"
  ]
  s.files = [
    "Blavosync.gemspec",
     "History.txt",
     "LICENSE",
     "Manifest.txt",
     "README.markdown",
     "Rakefile",
     "VERSION",
     "lib/blavosync.rb",
     "lib/blavosync/lib/ey_logger.rb",
     "lib/blavosync/lib/ey_logger_hooks.rb",
     "lib/blavosync/recipes.rb",
     "lib/blavosync/recipes/content_rsync.rb",
     "lib/blavosync/recipes/content_tar.rb",
     "lib/blavosync/recipes/database.rb",
     "lib/blavosync/recipes/local.rb",
     "lib/blavosync/recipes/util.rb",
     "test/test_blavosync.rb",
     "test/test_helper.rb"
  ]
  s.homepage = %q{http://github.com/indierockmedia/Blavosync}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{Sync a remote db and rsync content to your development environment.}
  s.test_files = [
    "test/test_blavosync.rb",
     "test/test_helper.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end

