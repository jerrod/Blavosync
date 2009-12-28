namespace :local do

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

def local_content_backup_dir(args={})
  timestamp = args[:timestamp] || current_timestamp
  "#{tmp_dir}/#{application}-#{from_env}-content-#{timestamp.to_s.strip}"
end


def generate_remote_content_backup
  run "cd #{shared_path} && tar czf #{tar_content_backup_file} 'system'"
end
