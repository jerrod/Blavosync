namespace :local do

  desc <<-DESC
    [capistrano-extensions]: Downloads a tarball of shared content (identified by the :shared_content and
    :content_directories properties) from a deployable environment (RAILS_ENV) to the local filesystem.
  DESC
  task :backup_content do
    from = ENV['FROM'] || 'production'

    # sort by last alphabetically (forcing the most recent timestamp to the top)
    files = retrieve_local_files('production', 'content')
    generate_remote_content_backup unless server_cache_valid?(content_backup_file)

    timestamp = most_recent_local_backup(from, 'content')
    should_redownload = !(most_recent_local_backup(from, 'content') == last_mod_time(content_backup_file))
    if should_redownload || last_mod_time(content_backup_file) == 0
      # pull it from the server
      generate_remote_content_backup unless server_cache_valid?(content_backup_file)
      system("mkdir -p #{tmp_dir}")

      download(content_backup_file, "#{local_content_backup_dir(:env => from, :timestamp=>last_mod_time(content_backup_file))}.tar.#{zip_ext}", :via=> :scp) do|ch, name, sent, total|
        print "\r\033[1;42m #{File.basename(name)}: #{sent}/#{total} -- #{(sent.to_f * 100 / total.to_f).to_i}% \033[0m"
      end
    else
      # set us up to use our local cache
      print "\r\033[1;42m Your Files are already up-to-date \033[0m\n"
      @current_timestamp = files.first.to_i # actually has the extension hanging off of it, but shouldn't be a problem
    end
    # Notify user if :tmp_dir is too large
    util::tmp::check
  end

  desc <<-DESC
    [capistrano-extensions]: Restores the backed up content (env var FROM specifies which environment
    was backed up, defaults to RAILS_ENV) to the local development environment app
  DESC
  task :restore_content do
    from = ENV['FROM'] || 'production'

    timestamp = most_recent_local_backup(from, 'content')
    local_dir = local_content_backup_dir(:env => from, :timestamp=>timestamp)
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
    [capistrano-extensions]: Wrapper for local:backup_content and local:restore_content
    $> cap local:sync_content RAILS_ENV=production RESTORE_ENV=development
  DESC
  task :sync_content do
    transaction do
      backup_content
      restore_content
    end
  end
end

def content_backup_file(env='production')
  "#{shared_path}/backup_#{env}_content.tar.#{zip_ext}"
end

def generate_remote_content_backup
  run "cd #{shared_path} && tar czf #{content_backup_file} 'system'"
end
