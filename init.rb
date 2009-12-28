load Dir[File.join(File.dirname(__FILE__), 'lib/shared_sync.rb')] #load shared first
Dir[File.join(File.dirname(__FILE__), 'lib/*.rb')].each { |file| load file }
