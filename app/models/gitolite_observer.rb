class GitoliteObserver < ActiveRecord::Observer
  observe :project, :user, :gitolite_public_key, :member, :role, :repository
  
  def after_save(object) ; update_repositories(object) ; end
  def after_destroy(object) ; update_repositories(object) ; end
  
  protected
  
  def update_repositories(object)
    case object
      when Repository then GitoliteRedmine::update_repositories(object.project)
      when User then GitoliteRedmine::update_repositories(object.projects) unless is_login_save?(object)
      when GitolitePublicKey then GitoliteRedmine::update_repositories(object.user.projects)
      when Member then GitoliteRedmine::update_repositories(object.project)
      when Role then GitoliteRedmine::update_repositories(object.members.map(&:project).uniq.compact)
    end
  end
  
  private
  
  # Test for the fingerprint of changes to the user model when the User actually logs in.
  def is_login_save?(user)
    user.changed? && user.changed.length == 2 && user.changed.include?("updated_on") && user.changed.include?("last_login_on")
  end
end
