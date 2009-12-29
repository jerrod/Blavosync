['lib/blavosync.rb','recipes/shared_sync.rb', 'recipes/content_rsync.rb', 'recipes/content_sync.rb', 'recipes/db_sync.rb'].each do |file| 
  load Dir[File.join(File.dirname(__FILE__), file)] 
end
