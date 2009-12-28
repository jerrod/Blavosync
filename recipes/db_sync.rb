namespace :local do
  desc <<-DESC
    Backs up deployable environment's database (identified by the
    RAILS_ENV environment variable, which defaults to 'production') and copies it to the local machine
  DESC
  task :backup_db, :roles => :db do
    files = retrieve_local_files(from_env, 'db')
    timestamp = most_recent_local_backup(from_env, 'db').to_i
    last_modified = last_mod_time(db_backup_zip_file).to_i

    if last_modified < (Time.now.to_i - (remote_backup_expires))
      generate_remote_db_backup
      should_redownload = true
    end
    should_redownload = !(timestamp == last_modified)
    if should_redownload
      system "mkdir -p #{tmp_dir}"
      download(db_backup_zip_file, "#{local_db_backup_file(:env=>from_env, :timestamp=>last_modified)}.#{zip_ext}", :via=> :scp) do|ch, name, sent, total|
        print "\r\033[1;42m  #{File.basename(name)}: #{sent}/#{total} -- #{(sent.to_f * 100 / total.to_f).to_i}% \033[0m"
      end
    else
      print "\r\033[1;42m Your Files are already up-to-date \033[0m\n"
      @current_timestamp = files.first.to_i
    end
  end

  desc <<-DESC
    Regenerate files.
  DESC
  task :force_backup_db do
    generate_remote_db_backup
  end

  desc <<-DESC
    Untars the backup file downloaded from local:backup_db (specified via the FROM env
    variable, which defalts to RAILS_ENV), and imports (via mysql command line tool) it back into the database
    defined in the RESTORE_ENV env variable (defaults to development).
  DESC
  task :restore_db, :roles => :db do
    mysql_str  = "mysql #{mysql_connection_for(to_env)}"
    mysql_dump = "mysqldump  #{mysql_connection_for(from_env)}"
    local_db_create = "mysql #{mysql_connection_for(to_env)} -e \"create database if not exists #{mysql_db_for(to_env)}\""
    remote_backup_file = local_db_backup_file(:env => from_env, :timestamp=>most_recent_local_backup(from_env, 'db')).strip

    puts "\n\033[1;42m Restoring database backup to #{to_env} environment FROM #{remote_backup_file}--#{from_env} using #{mysql_str}\033[0m"
    system(local_db_create.strip)
    cmd = ""
    cmd << <<-CMD
      #{unzip} -c #{remote_backup_file}.#{zip_ext} > #{remote_backup_file} &&
      #{mysql_str} < #{remote_backup_file} &&
      rm -f #{remote_backup_file}
    CMD
    system(cmd.strip)
    util::tmp::check
  end

  desc <<-DESC
    Wrapper for local:backup_db and local:restore_db.
    $> cap local:sync_db RAILS_ENV=production RESTORE_ENV=development
  DESC
  task :sync_db do
    transaction do
      backup_db
      restore_db
    end
  end

  desc <<-DESC
    Ensure that a fresh remote data dump is retrieved before syncing to the local environment.
  DESC
  task :resync_db do
    util::tmp::clean_remote
    sync_db
  end

end


def generate_remote_db_backup
  run "mysqldump  #{mysql_connection_for(from_env)} > #{db_backup_file}"
  run "rm -f #{db_backup_zip_file} && #{zip} #{db_backup_file} && rm -f #{db_backup_file}"
end

def local_db_backup_file(args = {})
  env = args[:env] || 'production'
  timestamp = args[:timestamp] || current_timestamp
  "#{tmp_dir}/#{application}-#{env}-db-#{timestamp.to_s.strip}.sql"
end

def mysql_connection_for(environment)
    db_settings = YAML.load_file(local_db_conf(environment))[environment]
    pass = pluck_pass_str(db_settings)
    host = (db_settings['host'].nil?) ? nil : "--host=#{db_settings['host']}"
    socket = (db_settings['socket'].nil?) ? nil : "--socket=#{db_settings['socket']}"
    user = (db_settings['username'].nil?) ? nil : "-u #{db_settings['username']}"
    database = (db_settings['database'].nil?) ? nil : " #{db_settings['database']}"
    [user, pass, host, socket, database ].join(" ")
end

def mysql_db_for(environment)
    restore_from = ENV['FROM'] || 'production'
    @from_db ||= YAML.load_file(local_db_conf(restore_from))[restore_from]
    @from_database ||= (@from_db['database'].nil?) ? nil : " #{@from_db['database']}"
end