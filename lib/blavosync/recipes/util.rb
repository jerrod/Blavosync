Capistrano::Configuration.instance(:must_exist).load do

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
        system("rm -rf #{rails_root}/#{tmp_dir}/#{configuration.fetch(:application)}-*")
      end

    end
  end
  
end