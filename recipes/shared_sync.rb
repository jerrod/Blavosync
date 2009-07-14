def rails_env
   ENV['RAILS_ENV'].nil? ? 'development' : ENV['RAILS_ENV']
end

def content_dir
  "system"
end

def content_path
  File.join(shared_path, content_dir)
end

def public_path
  File.join(latest_release, 'public')
end

def log_path
  "/var/log/#{application}"
end

def store_dev_backups
 false
end

def remote_backup_expires
 172800
end

def store_remote_backups
  true
end

def exclude_paths
  []
end

def zip
   "gzip"
end
def unzip
   "gunzip"
end
def zip_ext
   "gz"
end

def tmp_dir
"tmp/cap"
end

def local_db_conf(env = nil)
env ||= fetch(:rails_env)
fetch(:config_structure, :rails).to_sym == :sls ?
  File.join('config', env.to_s, 'database.yml') :
  File.join('config', 'database.yml')
end

def pluck_pass_str(db_config)
pass_str = db_config['password']
if !pass_str.nil?
  pass_str = "-p'#{pass_str}'"
end
pass_str || ''
end

def current_timestamp
  @current_timestamp ||= Time.now.to_i
end

def local_db_backup_file(args = {})
  env = args[:env] || 'production'
  timestamp = args[:timestamp] || current_timestamp
  "#{tmp_dir}/#{application}-#{env}-db-#{timestamp}.sql"
end

def local_content_backup_dir(args={})
  env = args[:env] || 'production'
  timestamp = args[:timestamp] || current_timestamp
  "#{tmp_dir}/#{application}-#{env}-content-#{timestamp}"
end

def retrieve_local_files(env, type)
  `ls -r #{tmp_dir} | awk -F"-" '{ if ($2 ~ /#{env}/ && $3 ~ /#{type}/) { print $4; } }'`.split(' ')
end

def most_recent_local_backup(env, type)
  retrieve_local_files(env, type).first.to_i
end


def last_mod_time(path)
  capture("stat -c%Y #{path}").to_i
end

def server_cache_valid?(path)
  capture("[ -f #{path} ] || echo '1'").empty? && ((Time.now.to_i - last_mod_time(path)) <= remote_backup_expires) # two days in seconds
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
      system("rm -f #{tmp_dir}/#{application}-#{rails_env}*")
    end

    # desc "Removes all but a single backup from :tmp_dir"
    # task :clean do
    #
    # end
    #
    # desc "Removes all tmp files from :tmp_dir"
    # task :remove do
    #
    # end
  end
end