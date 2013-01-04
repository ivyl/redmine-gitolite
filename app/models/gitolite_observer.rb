class GitoliteObserver < ActiveRecord::Observer
  unloadable

  observe :project, :user, :gitolite_public_key, :member, :role, :repository
  
  def after_save(object) ; update_repositories(object) ; end
  def after_destroy(object) ; update_repositories(object) ; end
  
  protected
  
  def update_repositories(object)
    gr = GitoliteRedmine::AdminHandler.new
    case object
      when Repository then gr.update_projects(object.project)
      when User then (gr.update_projects(object.projects) && gr.update_user(object)) unless is_login_save?(object)
      when GitolitePublicKey then gr.update_user(object.user)
      when Member then gr.update_projects(object.project)
      when Role then gr.update_projects(object.members.map(&:project).uniq.compact)
    end
  end
  
  private
  
  # Test for the fingerprint of changes to the user model when the User actually logs in.
  def is_login_save?(user)
    user.changed? && user.changed.length == 2 && user.changed.include?("updated_on") && user.changed.include?("last_login_on")
  end
end
