Capistrano::Configuration.instance(:must_exist).load do

    namespace :local do
    desc <<-DESC
      Backs up deployable environment's database (identified by the
      RAILS_ENV environment variable, which defaults to 'production') and copies it to the local machine
    DESC
    task :backup_db, :roles => :db do
      last_modified = Time.now.to_i
      generate_remote_db_backup
      system "mkdir -p #{tmp_dir}"
      download(db_schema_backup_zip_file, "#{local_db_schema_backup_file(:env=>from_env, :timestamp=>last_modified)}.#{zip_ext}", :via=> :scp) do|ch, name, sent, total|
        print "\r\033[1;42m  #{File.basename(name)}: #{sent}/#{total} -- #{(sent.to_f * 100 / total.to_f).to_i}% \033[0m"
      end
      download(db_backup_zip_file, "#{local_db_backup_file(:env=>from_env, :timestamp=>last_modified)}.#{zip_ext}", :via=> :scp) do|ch, name, sent, total|
        print "\r\033[1;42m  #{File.basename(name)}: #{sent}/#{total} -- #{(sent.to_f * 100 / total.to_f).to_i}% \033[0m"
      end
    end

    desc <<-DESC
      Untars the backup file downloaded from local:backup_db (specified via the FROM env
      variable, which defalts to RAILS_ENV), and imports (via mysql command line tool) it back into the database
      defined in the RESTORE_ENV env variable (defaults to development).
    DESC


    task :restore_db, :roles => :db do
      mysql_str  = "mysql #{mysql_connection_for(to_env)}"
      mysql_dump = "mysqldump  #{mysql_connection_for(from_env)}"
      local_db_create = "mysqladmin create #{mysql_connection_for(to_env)} " #  "create database if not exists #{mysql_db_for(to_env)}"
      remote_schema_backup_file = local_db_schema_backup_file(:env => from_env, :timestamp=>most_recent_local_backup(from_env, 'schema')).strip
      remote_backup_file = local_db_backup_file(:env => from_env, :timestamp=>most_recent_local_backup(from_env, 'db')).strip

      puts "\n\033[1;42m Attempting to create #{to_env} database \033[0m"
      system(local_db_create.strip)
      cmd = ""

      puts "\n\033[1;42m Restoring database schema to #{to_env} environment FROM #{remote_schema_backup_file}--#{from_env} using #{mysql_str}\033[0m"
      cmd << <<-CMD
        #{unzip} -c #{remote_schema_backup_file}.#{zip_ext} > #{remote_schema_backup_file} &&
        #{mysql_str} < #{remote_schema_backup_file} &&
        rm -f #{remote_schema_backup_file}
      CMD

     puts "\n\033[1;42m Restoring database data to #{to_env} environment FROM #{remote_backup_file}--#{from_env} using #{mysql_str}\033[0m"

      cmd << <<-CMD
        #{unzip} -c #{remote_backup_file}.#{zip_ext} > #{remote_backup_file} &&
        #{mysql_str} < #{remote_backup_file} &&
        rm -f #{remote_backup_file}
      CMD
      system(cmd.strip)
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
  end

end