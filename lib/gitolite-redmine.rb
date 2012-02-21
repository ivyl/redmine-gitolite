require 'lockfile'
require 'gitolite'
require 'net/ssh'
require 'tmpdir'

module GitoliteRedmine
	def self.update_repositories(projects)

		begin

			projects = (projects.is_a?(Array) ? projects : [projects])
		
			if(defined?(@recursionCheck))
				if(@recursionCheck)
					return
				end
			end
			@recursionCheck = true

			# Don't bother doing anything if none of the projects we've been handed have a Git repository
			unless projects.detect{|p|  p.repository.is_a?(Repository::Git)}.nil?

				lockfile=File.new(File.join(RAILS_ROOT,"tmp",'redmine_gitolite_lock'),File::CREAT|File::RDONLY)
				retries=5
				loop do
					break if lockfile.flock(File::LOCK_EX|File::LOCK_NB)
					retries-=1
					sleep 2
					raise Lockfile::MaxTriesLockError if retries<=0
				end


				# HANDLE GIT

				# create tmp dir
				local_dir = File.join(RAILS_ROOT,"tmp","redmine_gitolite_#{Time.now.to_i}")

				Dir.mkdir local_dir

				# clone repo
				`git clone #{Setting.plugin_redmine_gitolite['gitoliteUrl']} #{local_dir}/repo`
	      
	      ga_repo = Gitolite::GitoliteAdmin.new "#{local_dir}/repo"

				projects.select{|p| p.repository.is_a?(Repository::Git)}.each do |project|
					# fetch users
					users = project.member_principals.map(&:user).compact.uniq
					write_users = users.select{ |user| user.allowed_to?( :commit_access, project ) }
					read_users = users.select{ |user| user.allowed_to?( :view_changesets, project ) && !user.allowed_to?( :commit_access, project ) }
					# write key files
					users.map{|u| u.gitolite_public_keys.active}.flatten.compact.uniq.each do |key|
	          parts = key.key.split
	          k = ga_repo.ssh_keys[key.user.login.underscore].find_all{|k|k.location == key.title.underscore && k.owner == key.user.login.underscore}.first
	          if k
	            k.type = parts[0]
	            k.blob = parts[1]
	            k.email = parts[2]
	            k.owner = key.user.login.underscore
	          else
	            k = Gitolite::SSHKey.new(parts[0], parts[1], parts[2])
	            k.location = key.title.underscore
	            k.owner = key.user.login.underscore
	            ga_repo.add_key k
	          end
					end

					# delete inactives
					users.map{|u| u.gitolite_public_keys.inactive}.flatten.compact.uniq.each do |key|
	          k = ga_repo.ssh_keys[key.user.login.underscore].find_all{|k|k.location == key.title.underscore && k.owner == key.user.login.underscore}.first
						ga_repo.rm_key k if k
					end
	      
					# write config file
	        name = "#{project.identifier}"
					conf = ga_repo.config.repos[name]
	        unless conf
	          conf = Gitolite::Config::Repo.new(name)
	          ga_repo.config.add_repo(conf)
	        end
	        
	        write = write_users.map{|usr| usr.login.underscore}.sort
	        
	        read = read_users.map{|usr| usr.login.underscore}.sort
	        read << "daemon" if User.anonymous.allowed_to?(:view_changesets, project)
	        read << "gitweb" if User.anonymous.allowed_to?(:view_gitweb, project)
	        
	        read << "redmine"

	        permissions = {}
	        permissions["RW+"] = {"" => write} unless write.empty?
	        permissions["R"] = {"" => read} unless read.empty?
	        conf.permissions = [permissions]
				end
	      
	      ga_repo.save
	      ga_repo.apply
				
	      #remove local copy
			  `rm -Rf #{local_dir}`

				lockfile.flock(File::LOCK_UN)
			end
			@recursionCheck = false

	    rescue Exception => e:
	      @recursionCheck = false
	    end
	end
	
end
