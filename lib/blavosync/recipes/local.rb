# set :rails_root,                fetch(:blavosync_local_root,                Pathname.new('.').realpath                                   )
# set :content_dir,               fetch(:blavosync_content_directories,       "system"                                                     )
# set :content_path,              fetch(:blavosync_content_path,              File.join(fetch(:shared_path), content_dir)    )
# set :public_path,               fetch(:blavosync_public_path,               File.join(fetch(:latest_release), 'public')    )
# set :remote_backup_expires,     fetch(:blavosync_remote_backup_expires,     100000                                                       )
# set :zip,                       fetch(:blavosync_zip_command,               "gzip"                                                       )
# set :unzip,                     fetch(:blavosync_unzip_command,             "gunzip"                                                     )
# set :zip_ext,                   fetch(:blavosync_compressed_extension,      "gz"                                                         )
# set :tmp_dir,                   fetch(:blavosync_tmp_dir,                   "tmp"                                                        )
# set :content_sync_method,       fetch(:blavosync_content_sync_method,       'rsync'                                                      )
# set :from_env,                  fetch(:blavosync_from_env,                  (ENV['FROM_ENV'].nil? ? 'production' : ENV['RAILS_ENV'])     )
# set :to_env,                    fetch(:blavosync_to_env,                    (ENV['TO_ENV'].nil? ? 'development' : ENV['TO_ENV'])         )
# set :rsync_content_backup_file, fetch(:blavosync_rsync_content_backup_file, "#{shared_path}/system"                                      )
# set :tar_content_backup_file,   fetch(:blavosync_tar_content_backup_file,   "#{shared_path}/backup_#{from_env}_content.tar.#{zip_ext}"   )
# set :db_backup_file,            fetch(:blavosync_db_backup_file,            "#{shared_path}/backup_#{from_env}_db.sql"                   )
# set :db_backup_zip_file,        fetch(:blavosync_db_backup_zip_file,        "#{db_backup_file}.#{zip_ext}"                               )
# 
Capistrano::Configuration.instance(:must_exist).load do |configuration|

  def rails_root
    Pathname.new('.').realpath
  end
  def content_dir                                                
    exists?(:content_directory) ? fetch(:content_directory) : "system"                                                     
  end
  def content_path                                               
    File.join(fetch(:shared_path), content_dir)                 
  end                                              
  def public_path                                               
    File.join(fetch(:latest_release), 'public')                 
  end
  def remote_backup_expires                                      
    100000                                                       
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
    "tmp"                                                        
  end
  def content_sync_method                                      
    exists?(:sync_method) ? sync_method : 'rsync'                                                      
  end
  def from_env                                                  
    (ENV['FROM_ENV'].nil? ? 'production' : ENV['RAILS_ENV'])     
  end
  def to_env                                                  
    (ENV['TO_ENV'].nil? ? 'development' : ENV['TO_ENV'])         
  end
  def rsync_content_backup_file 
    "#{shared_path}/#{content_dir}"  
  end
  def tar_content_backup_file                                   
    "#{shared_path}/backup_#{from_env}_content.tar.#{zip_ext}"   
  end
  def db_backup_file                                           
    "#{shared_path}/backup_#{from_env}_db.sql"                   
  end
  def db_backup_zip_file                                        
    "#{db_backup_file}.#{zip_ext}"                               
  end
 
  def local_content_backup_dir(args={})
    timestamp = args[:timestamp] || current_timestamp
    "#{tmp_dir}/#{fetch(:application)}-#{from_env}-content-#{timestamp.to_s.strip}"
  end
  
  def generate_remote_tar_content_backup
    run "cd #{fetch(:shared_path)} && tar czf #{rsync_content_backup_file} 'system'"
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
    capture("stat -c%Y #{path}") rescue 0
  end
  
  def generate_remote_db_backup
    run "mysqldump  #{mysql_connection_for(from_env)} > #{db_backup_file}"
    run "rm -f #{db_backup_zip_file} && #{zip} #{db_backup_file} && rm -f #{db_backup_file}"
  end
  
  def local_db_backup_file(args = {})
    env = args[:env] || 'production'
    timestamp = args[:timestamp] || current_timestamp
    "#{tmp_dir}/#{fetch(:application)}-#{env}-db-#{timestamp.to_s.strip}.sql"
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
  
  namespace :local do
  
    desc <<-DESC
      Wrapper for local:sync_db and local:sync_content
      $> cap local:sync RAILS_ENV=production RESTORE_ENV=development
    DESC
    task :sync, :roles =>:app do
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
    task :sync_init, :roles =>:app  do
      force_backup_db
      force_backup_content
      sync
    end 
      
  end

end