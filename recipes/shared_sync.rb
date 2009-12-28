set :rails_env,    (ENV['RAILS_ENV'].nil? ? 'development' : ENV['RAILS_ENV'])
set :rails_root,   Pathname.new('.').realpath
set :content_dir,  (content_directories ||= "system")
set :content_path, File.join(shared_path, content_dir)
set :public_path,  File.join(latest_release, 'public')
set :remote_backup_expires, 100000
set :zip,      "gzip"
set :unzip,    "gunzip"
set :zip_ext,  "gz"
set :tmp_dir,  "tmp"
set :content_sync_method, ( sync_method ||= 'rsync')
set :from_env, 'production'
set :to_env,   'development'
set :rsync_content_backup_file,  "#{shared_path}/system"
set :tar_content_backup_file, "#{shared_path}/backup_#{from_env}_content.tar.#{zip_ext}"

set :db_backup_file, "#{shared_path}/backup_#{from_env}_db.sql"
set :db_backup_zip_file, "#{db_backup_file}.#{zip_ext}"
def local_db_conf(env = nil)
  env ||= fetch(:rails_env)
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
  
  task :test_root do
    puts "RAILS_ROOT #{rails_root}"
  end
end