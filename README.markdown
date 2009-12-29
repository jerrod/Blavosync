== blavosync

INSTALLATION:
Add this line to your config/deploy.rb file

  require 'blavosync/recipes'

USAGE:
adds the following tasks to projects using capistrano

------------------------------------------------------------
cap local:backup_content
------------------------------------------------------------
Downloads a tarball of shared content (identified by the :shared_content and
:content _ directories properties) from a deployable environment (RAILS_ENV) to
the local filesystem.

------------------------------------------------------------
cap local:backup _ db
------------------------------------------------------------
Backs up deployable environment's database and copies it to
the local machine.

------------------------------------------------------------
cap local:force _ backup _ content
------------------------------------------------------------
Regenerate files.

------------------------------------------------------------
cap local:force _ backup _ db
------------------------------------------------------------
Regenerate files.

------------------------------------------------------------
cap local:restore _ content
------------------------------------------------------------
Restores the backed up content (env var FROM specifies which environment
was backed up, defaults to RAILS_ENV) to the local development environment app

------------------------------------------------------------
cap local:restore _ db
------------------------------------------------------------
Untars the backup file downloaded from local:backup_db and imports 
(via mysql command line tool) it back into the development database.

------------------------------------------------------------
cap local:resync _ db
------------------------------------------------------------
Ensure that a fresh remote data dump is retrieved before syncing to the local
environment

------------------------------------------------------------
cap local:sync
------------------------------------------------------------
Wrapper for local:sync _ db and local:sync _ content
$> cap local:sync

------------------------------------------------------------
cap local:sync_content
------------------------------------------------------------
Wrapper for local:backup _ content and local:restore _ content
$> cap local:sync_content

------------------------------------------------------------
cap local:sync_db
------------------------------------------------------------
Wrapper for local:backup _ db and local:restore _ db.
$> cap local:sync _ db

------------------------------------------------------------
cap local:sync_init
------------------------------------------------------------
Wrapper for local:force _ backup _ db, local:force _ backup _ content, and the
local:sync to get
a completely fresh set of data from the server
$> cap local:sync


== Note on Patches/Pull Requests
 
* Fork the project.
* Make your feature addition or bug fix.
* Add tests for it. This is important so I don't break it in a
  future version unintentionally.
* Commit, do not mess with rakefile, version, or history.
  (if you want to have your own version, that is fine but bump version in a commit by itself I can ignore when I pull)
* Send me a pull request. Bonus points for topic branches.

== Copyright

Copyright (c) 2009 jayronc. See LICENSE for details.
