Capistrano::Configuration.instance(:must_exist).load do

  set :rails_root,                fetch(:blavosync_local_root,                Pathname.new('.').realpath                                   )
  set :content_dir,               fetch(:blavosync_content_directories,       content_directories ||= "system"                             )
  set :content_path,              fetch(:blavosync_content_path,              File.join(shared_path, content_dir)                          )
  set :public_path,               fetch(:blavosync_public_path,               File.join(latest_release, 'public')                          )
  set :remote_backup_expires,     fetch(:blavosync_remote_backup_expires,     100000                                                       )
  set :zip,                       fetch(:blavosync_zip_command,               "gzip"                                                       )
  set :unzip,                     fetch(:blavosync_unzip_command,             "gunzip"                                                     )
  set :zip_ext,                   fetch(:blavosync_compressed_extension,      "gz"                                                         )
  set :tmp_dir,                   fetch(:blavosync_tmp_dir,                   "tmp"                                                        )
  set :content_sync_method,       fetch(:blavosync_content_sync_method,       'rsync'                                                      )
  set :from_env,                  fetch(:blavosync_from_env,                  (ENV['FROM_ENV'].nil? ? 'production' : ENV['RAILS_ENV'])     )
  set :to_env,                    fetch(:blavosync_to_env,                    (ENV['TO_ENV'].nil? ? 'development' : ENV['TO_ENV'])         )
  set :rsync_content_backup_file, fetch(:blavosync_rsync_content_backup_file, "#{shared_path}/system"                                      )
  set :tar_content_backup_file,   fetch(:blavosync_tar_content_backup_file,   "#{shared_path}/backup_#{from_env}_content.tar.#{zip_ext}"   )
  set :db_backup_file,            fetch(:blavosync_db_backup_file,            "#{shared_path}/backup_#{from_env}_db.sql"                   )
  set :db_backup_zip_file,        fetch(:blavosync_db_backup_zip_file,        "#{db_backup_file}.#{zip_ext}"                               )

  def local_content_backup_dir(args={})
    timestamp = args[:timestamp] || current_timestamp
    "#{tmp_dir}/#{application}-#{from_env}-content-#{timestamp.to_s.strip}"
  end

  def generate_remote_tar_content_backup
    run "cd #{shared_path} && tar czf #{rsync_content_backup_file} 'system'"
  end

  def local_db_conf(env = nil)
    env ||= fetch(:to_env)
    fetch(:config_structure, :rails).to_sym == :sls ?
      File.join('config', env.to_s, 'database.yml') :
      File.join('config', 'database.yml')
  end

  def pluck_pass_str(db_config)
     db_config['password'].nil? ? '' : "-p'#{db_config['password']}'"
  end

  def current_timestamp
    @current_timestamp ||= Time.now.to_i.to_s.strip
  end

  def retrieve_local_files(env, type)
    `ls -r #{tmp_dir} | awk -F"-" '{ if ($2 ~ /#{env}/ && $3 ~ /#{type}/) { print $4; } }'`.split(' ')
  end

  def most_recent_local_backup(env, type)
    retrieve_local_files(env, type).first.to_i
  end

  def last_mod_time(path)
    capture("stat -c%Y #{path}")
  end

  def server_cache_valid?(path)
    capture("[ -f #{path} ] || echo '1'").empty? && ((Time.now.to_i - last_mod_time(path)) <= remote_backup_expires)
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

  namespace :util do

    namespace :tmp do
      desc "[capistrano-extensions]: Displays warning if :tmp_dir has more than 10 files or is greater than 50MB"
      task :check do
        #[ 5 -le "`ls -1 tmp/cap | wc -l`" ] && echo "Display Me"
        cmd = %Q{ [ 10 -le "`ls -1 #{tmp_dir} | wc -l`" ] || [ 50 -le "`du -sh #{tmp_dir} | awk '{print int($1)}'`" ] && printf "\033[1;41m Clean up #{tmp_dir} directory \033[0m\n" && du -sh #{tmp_dir}/*  }
        system(cmd)
      end

      desc "[capistrano-extensions]: Remove the current remote env's backups from :tmp_dir"
      task :clean_remote do
        system("rm -rf #{rails_root}/#{tmp_dir}/#{fetch(:application)}-*")
      end

    end
  end

  namespace :local do

    desc <<-DESC
      Wrapper for local:sync_db and local:sync_content
      $> cap local:sync RAILS_ENV=production RESTORE_ENV=development
    DESC
    task :sync do
      sync_db
      if content_sync_method == 'tar'
        sync_content
      else
        rsync_content
      end
    end
  
    desc <<-DESC
      Wrapper for local:force_backup_db, local:force_backup_content, and the local:sync to get 
      a completely fresh set of data from the server
      $> cap local:sync RAILS_ENV=production RESTORE_ENV=development
    DESC
    task :sync_init do
      force_backup_db
      force_backup_content
      sync
    end 
  
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

    desc <<-DESC
      Rsyncs the your production content (identified by the :shared_content and
      :content_directories properties) from a deployable environment (RAILS_ENV) to the local filesystem.
    DESC
    task :rsync_content do
      from = ENV['FROM'] || 'production'
      system("rsync -avz -e ssh '#{user}@#{domain}:#{content_path}' '#{rails_root}/tmp/'")
    end

    desc <<-DESC
      Creates a symlink to public/system from tmp/system
    DESC
    task :rsync_restore_content do
      # from = ENV['FROM'] || 'production'
      print "\033[1;45m Linking Assets to public directory \033[0m\n"
      system "ln -nfs #{rails_root}/tmp/system #{rails_root}/public/system"
    end


    desc <<-DESC
      Wrapper for local:rsync_content and local:rsync_restore_content
      $> cap local:rsync RAILS_ENV=production
    DESC
    task :rsync do
      transaction do
        rsync_content
        rsync_restore_content
      end
    end

    desc <<-DESC
      Downloads a tarball of shared content (identified by the :shared_content and
      :content_directories properties) from a deployable environment (RAILS_ENV) to the local filesystem.
    DESC
    task :backup_content do
      files = retrieve_local_files('production', 'content')
      timestamp = most_recent_local_backup(from_env, 'content').to_i
      last_modified = last_mod_time(content_backup_file).to_i
      should_redownload = !(timestamp == last_modified)
      if should_redownload
        generate_remote_content_backup if last_modified < (Time.now.to_i - (remote_backup_expires))
        system("mkdir -p #{tmp_dir}")
        download(content_backup_file, "#{local_content_backup_dir(:env => from_env, :timestamp=>last_modified)}.tar.#{zip_ext}", :via=> :scp) do|ch, name, sent, total|
          print "\r\033[1;42m #{File.basename(name)}: #{sent}/#{total} -- #{(sent.to_f * 100 / total.to_f).to_i}% \033[0m"
        end
      else
        print "\r\033[1;42m Your Files are already up-to-date \033[0m\n"
        @current_timestamp = files.first.to_i
      end
      util::tmp::check
    end

    desc <<-DESC
      Regenerate files.
    DESC
    task :force_backup_content do
      generate_remote_content_backup
    end

    desc <<-DESC
      Restores the backed up content (env var FROM specifies which environment
      was backed up, defaults to RAILS_ENV) to the local development environment app
    DESC
    task :restore_content do
      timestamp = most_recent_local_backup(from_env, 'content')
      local_dir = local_content_backup_dir(:env => from_env, :timestamp=>timestamp)
      print "\033[1;45m Local Dir: #{local_dir} \033[0m\n"
      system "mkdir -p #{local_dir}"
      system "tar xzf #{local_dir}.tar.#{zip_ext} -C #{local_dir}"
      print "\033[1;45m Removing old public/system directory \033[0m\n"
      system "rm -rf public/system"
      print "\033[1;45m Moving Assets to public directory \033[0m\n"
      system "mv #{local_dir}/system public/system"
      print "\033[1;41m Cleaning up \033[0m\n"
      system "rm -rf #{local_dir}"
    end


    desc <<-DESC
      Wrapper for local:backup_content and local:restore_content
      $> cap local:sync_content RAILS_ENV=production RESTORE_ENV=development
    DESC
    task :sync_content do
      transaction do
        backup_content
        restore_content
      end
    end
  end

end