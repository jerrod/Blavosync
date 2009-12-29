Capistrano::Configuration.instance(:must_exist).load do
    namespace :local do
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
    end  
end    