require 'redmine'
require_dependency 'project'
require_dependency 'principal'
require_dependency 'user'

require_dependency 'gitolite_redmine'
require_dependency 'gitolite/patches/repositories_controller_patch'
require_dependency 'gitolite/patches/repositories_helper_patch'

Redmine::Plugin.register :redmine_gitolite do
  name 'Redmine Gitolite plugin'
  author 'Arkadiusz Hiler, Joshua Hogendorn, Jan Schulz-Hofen, Kah Seng Tay, Jakob Skjerning'
  description 'Enables Redmine to manage gitolite repositorie.'
  version '0.0.2'

  requires_redmine :version_or_higher => '2.0.0'
  url 'https://github.com/ivyl/redmine-gitolite/'
  author_url 'http://ivyl.0xcafe.eu/'

  settings({
    :partial => 'settings/redmine_gitolite',
    :default => {
      'redmineUser' => 'redmine',
      'gitoliteUrl' => 'gitolite@localhost:gitolite-admin.git',
      'developerBaseUrls' => "git@example.com:%{name}.git",
      'readOnlyBaseUrls' => 'http://example.com/git/%{name}',
      'basePath' => '/home/redmine/repositories/',
	}
  })
end

# initialize hook
class GitolitePublicKeyHook < Redmine::Hook::ViewListener
  render_on :view_my_account_contextual, :inline => "| <%= link_to(l(:label_public_keys), public_keys_path) %>" 
end

class GitoliteProjectShowHook < Redmine::Hook::ViewListener
  render_on :view_projects_show_left, :partial => 'redmine_gitolite'
end

# initialize association from user -> public keys
User.send(:has_many, :gitolite_public_keys, :dependent => :destroy)

# initialize observer
ActiveRecord::Base.observers = ActiveRecord::Base.observers << GitoliteObserver
