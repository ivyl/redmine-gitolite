require 'redmine'
require_dependency 'principal'
require_dependency 'user'

require_dependency 'gitolite-redmine'
require_dependency 'gitolite/patches/repositories_controller_patch'
require_dependency 'gitolite/patches/repositories_helper_patch'
require_dependency 'gitolite/patches/git_adapter_patch'

Redmine::Plugin.register :redmine_gitolite do
  name 'Redmine Gitolite plugin'
  author 'Arkadiusz Hiler, Joshua Hogendorn, Jan Schulz-Hofen'
  description 'Enables Redmine to update a gitolite server.'
  version '0.0.1'
  settings :default => {
    'gitoliteUrl' => 'gitolite@localhost:gitolite-admin.git',
    'gitoliteIdentityFile' => '/srv/projects/redmine/miner/.ssh/id_rsa',
    'developerBaseUrls' => 'git@www.salamander-linux.com:,https://[user]@www.salamander-linux.com/git/',
    'readOnlyBaseUrls' => 'http://example.com/git/%{name}',
    'basePath' => '/home/redmine/repositories/',
    }, 
    :partial => 'redmine_gitolite'
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
