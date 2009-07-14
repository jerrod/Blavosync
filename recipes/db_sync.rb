namespace :remote do
  # desc <<-DESC
  #   [capistrano-extensions] Uploads the backup file downloaded from local:backup_db (specified via the FROM env variable),
  #   copies it to the remote environment specified by RAILS_ENV, and imports (via mysql command line tool) it back into the
  #   remote database.
  # DESC
  # task :restore_db, :roles => :db do
  #   from = ENV['FROM'] || 'production'
  #   env  = ENV['RESTORE_ENV'] || 'development'
  #
  #   db = YAML.load_file(local_db_conf(from))[from]
  #   # print db.to_yaml
  #   pass_str = pluck_pass_str(db)
  #
  #   puts "\033[1;42m Restoring database backup to #{rails_env} environment \033[0m"
  #   if deployable_environments.include?(rails_env.to_sym)
  #     generate_remote_db_backup if store_remote_backups
  #
  #     # remote environment
  #     local_backup_file = local_db_backup_file(:timestamp => most_recent_local_backup(env, 'db'), :env => env) + ".#{zip_ext}"
  #     remote_file       = "#{shared_path}/restore_#{env}_db.sql"
  #
  #     if !File.exists?(local_backup_file)
  #       puts "Could not find backup file: #{local_backup_file}"
  #       exit 1
  #     end
  #     upload(local_backup_file, "#{remote_file}.#{zip_ext}", :via=> :scp) do|ch, name, sent, total|
  #       print " \r\033[1;42m  #{File.basename(name)}: #{sent}/#{total} -- #{(sent.to_f * 100 / total.to_f).to_i}% \033[0m"
  #     end
  #
  #     pass_str = pluck_pass_str(db)
  #     run "#{unzip} -c #{remote_file}.#{zip_ext} > #{remote_file}"
  #     run "mysql -u#{db['username']} #{pass_str} #{db['database']} < #{remote_file}"
  #     run "rm -f #{remote_file}"
  #   end
  # end
  #
  # desc <<-DESC
  #   [capistrano-extensions]: Backs up target deployable environment's database (identified
  #   by the FROM environment variable, which defaults to 'production') and restores it to
  #   the remote database identified by the TO environment variable, which defaults to "staging."
  # DESC
  # task :sync_db do
  #   system("capistrano-extensions-sync-db #{ENV['FROM'] || 'production'} #{ENV['TO'] || 'development'}")
  # end
end

namespace :local do
  desc <<-DESC
    [capistrano-extensions]: Backs up deployable environment's database (identified by the
    RAILS_ENV environment variable, which defaults to 'production') and copies it to the local machine
  DESC
  task :backup_db, :roles => :db do
    from = ENV['FROM'] || 'production'
    env  = ENV['RESTORE_ENV'] || 'development'
    # sort by last alphabetically (forcing the most recent timestamp to the top)
    files = retrieve_local_files(from, 'db')

    timestamp = most_recent_local_backup(from, 'db')
    should_redownload = !(most_recent_local_backup(from, 'db') == last_mod_time(db_backup_zip_file))

    if should_redownload
      # pull it from the server
      generate_remote_db_backup unless server_cache_valid?(db_backup_zip_file)
      system "mkdir -p #{tmp_dir}"
      download(db_backup_zip_file, "#{local_db_backup_file(:env=>from, :timestamp=>last_mod_time(db_backup_zip_file))}.#{zip_ext}", :via=> :scp) do|ch, name, sent, total|
        print "\r\033[1;42m  #{File.basename(name)}: #{sent}/#{total} -- #{(sent.to_f * 100 / total.to_f).to_i}% \033[0m"
      end
    else
      # set us up to use our local cache
      print "\r\033[1;42m Your Files are already up-to-date \033[0m\n"
      @current_timestamp = files.first.to_i # actually has the extension hanging off of it, but shouldn't be a problem
    end
  end

  desc <<-DESC
    [capistrano-extensions] Untars the backup file downloaded from local:backup_db (specified via the FROM env
    variable, which defalts to RAILS_ENV), and imports (via mysql command line tool) it back into the database
    defined in the RESTORE_ENV env variable (defaults to development).
  DESC
  task :restore_db, :roles => :db do
    from = ENV['FROM'] || 'production'
    env  = ENV['RESTORE_ENV'] || 'development'

    from_db = YAML.load_file(local_db_conf(from))[from]
    to_db = YAML.load_file(local_db_conf(env))[env]

    from_pass_str = pluck_pass_str(from_db)
    to_pass_str = pluck_pass_str(to_db)

    mysql_str  = "mysql -u#{to_db['username']} #{to_pass_str} #{to_db['database']}"
    mysql_dump = "mysqldump --add-drop-database -u#{from_db['username']} #{from_pass_str} #{from_db['database']}"
    local_db_create = "mysql -u#{to_db['username']} #{to_pass_str} -e \"create database if not exists #{to_db['database']}\""

    local_backup_file  = local_db_backup_file(:env => env, :timestamp=>most_recent_local_backup(env, 'db'))
    remote_backup_file = local_db_backup_file(:env => from, :timestamp=>most_recent_local_backup(from, 'db'))

    puts "\n\033[1;42m Restoring database backup to #{env} environment \033[0m"
    system(local_db_create.strip)
    # local
    cmd = ""
    cmd << <<-CMD
      #{unzip} -c #{remote_backup_file}.#{zip_ext} > #{remote_backup_file} &&
      #{mysql_str} < #{remote_backup_file} &&
      rm -f #{remote_backup_file}
    CMD
    system(cmd.strip)

    # Notify user if :tmp_dir is too large
    util::tmp::check
  end

  desc <<-DESC
    [capistrano-extensions]: Wrapper for local:backup_db and local:restore_db.
    $> cap local:sync_db RAILS_ENV=production RESTORE_ENV=development
  DESC
  task :sync_db do
    transaction do
      backup_db
      ENV['FROM'] = 'production'
      restore_db
    end
  end

  desc <<-DESC
    [capistrano-extensions]: Ensure that a fresh remote data dump is retrieved before syncing to the local environment.
  DESC
  task :resync_db do
    util::tmp::clean_remote
    sync_db
  end

end

def db_backup_file
  from = ENV['FROM'] || 'production'
  "#{shared_path}/backup_#{from}_db.sql"
end

def db_backup_zip_file
  "#{db_backup_file}.#{zip_ext}"
end

def generate_remote_db_backup
  from = ENV['FROM'] || 'production'
  env  = ENV['RESTORE_ENV'] || 'development'

  db = YAML.load_file(local_db_conf(from))[from]
  pass_str = pluck_pass_str(db)
  run "mysqldump --add-drop-database -u#{db['username']} #{pass_str} #{db['database']} > #{db_backup_file}"
  run "rm -f #{db_backup_zip_file} && #{zip} #{db_backup_file} && rm -f #{db_backup_file}"
end


namespace :local do
  desc <<-DESC
    [capistrano-extensions]: Wrapper for local:sync_db and local:sync_content
    $> cap local:sync RAILS_ENV=production RESTORE_ENV=development
  DESC
  task :sync do
    sync_db
    sync_content
  end
end