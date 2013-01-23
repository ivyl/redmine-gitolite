require 'lockfile'
require 'gitolite'
require 'fileutils'
require 'net/ssh'
require 'tmpdir'

module GitoliteRedmine
  class AdminHandler
    @@recursionCheck = false
    
    def update_user(user)
      recursion_check do 
        if lock
          clone(Setting.plugin_redmine_gitolite['gitoliteUrl'], local_dir)
          
          logger.debug "[Gitolite] Handling #{user.inspect}"
          add_active_keys(user.gitolite_public_keys.active)
          remove_inactive_keys(user.gitolite_public_keys.inactive)
          
          @repo.save
          @repo.apply
          FileUtils.rm_rf local_dir
          unlock
        end
      end
    end
    
    def update_projects(projects)
      recursion_check do
        projects = (projects.is_a?(Array) ? projects : [projects])

        if projects.detect{|p| p.repository.is_a?(Repository::Git)} && lock
          clone(Setting.plugin_redmine_gitolite['gitoliteUrl'], local_dir)
          
          projects.select{|p| p.repository.is_a?(Repository::Git)}.each do |project|
            logger.debug "[Gitolite] Handling #{project.inspect}"
            handle_project project
          end

          @repo.save
          @repo.apply
          FileUtils.rm_rf local_dir
          unlock
        end
      end
    end
    
    private
    
    def local_dir
      @local_dir ||= File.join(Rails.root, "tmp", "redmine_gitolite_#{Time.now.to_i}")
    end
    
    def clone(origin, local_dir)
      FileUtils.mkdir_p local_dir
      result = `git clone #{origin} #{local_dir}`
      logger.debug result
      @repo = Gitolite::GitoliteAdmin.new local_dir
    end
    
    def lock
      lockfile_path = File.join(::Rails.root,"tmp",'redmine_gitolite_lock')
      @lockfile = File.new(lockfile_path, File::CREAT|File::RDONLY)
      retries = 5
      while (retries -= 1) > 0
        return @lockfile if @lockfile.flock(File::LOCK_EX|File::LOCK_NB)
        sleep 2
      end
      false
    end
    
    def unlock
      @lockfile.flock(File::LOCK_UN)
    end
    
    def handle_project(project)
      users = project.member_principals.map(&:user).compact.uniq
      
      name = project.identifier.to_s
      conf = @repo.config.repos[name]
      
      unless conf
        conf = Gitolite::Config::Repo.new(name)
        @repo.config.add_repo(conf)
      end
      
      conf.permissions = build_permissions(users, project)
    end
    
    def add_active_keys(keys) 
      keys.each do |key|
        parts = key.key.split
        repo_keys = @repo.ssh_keys[key.owner]
        repo_key = repo_keys.find_all{|k| k.location == key.location && k.owner == key.owner}.first
        if repo_key
          repo_key.type, repo_key.blob, repo_key.email = parts
          repo_key.owner = key.owner
        else
          repo_key = Gitolite::SSHKey.new(parts[0], parts[1], parts[2])
          repo_key.location = key.location
          repo_key.owner = key.owner
          @repo.add_key repo_key
        end
      end
    end
    
    def remove_inactive_keys(keys)
      keys.each do |key|
        repo_keys = @repo.ssh_keys[key.owner]
        repo_key = repo_keys.find_all{|k| k.location == key.location && k.owner == key.owner}.first
        @repo.rm_key repo_key if repo_key
      end
    end
    
    def build_permissions(users, project)
      write_users = users.select{|user| user.allowed_to?(:commit_access, project) }
      read_users = users.select{|user| user.allowed_to?(:view_changesets, project) && !user.allowed_to?(:commit_access, project) }
      
      write = write_users.map{|usr| usr.login.underscore.gsub(/[^0-9a-zA-Z\-\_]/,'_')}.sort
      read = read_users.map{|usr| usr.login.underscore.gsub(/[^0-9a-zA-Z\-\_]/,'_')}.sort
      
      read << Setting.plugin_redmine_gitolite['redmineUser']
      read << "daemon" if User.anonymous.allowed_to?(:view_changesets, project)
      read << "gitweb" if User.anonymous.allowed_to?(:view_gitweb, project)
      
      permissions = {}
      permissions["RW+"] = {"" => write} unless write.empty?
      permissions["R"] = {"" => read} unless read.empty?
      
      [permissions]
    end
    
    def recursion_check
      return if @@recursionCheck
      begin
        @@recursionCheck = true
        yield
      rescue Exception => e
        logger.error "#{e.inspect} #{e.backtrace}"
      ensure
        @@recursionCheck = false
      end
    end
    
    def logger
      Rails.logger
    end
  end
end
