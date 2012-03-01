require 'open3'

class GitoliteHookController < ApplicationController

  skip_before_filter :verify_authenticity_token, :check_if_login_required

  def index
    repository = find_repository
    update_repository(repository)
    repository.fetch_changesets
    render(:text => 'OK')
  end

  private

  def exec(command)
    logger.debug { "GitoliteHook: Executing command: '#{command}'" }
    stdin, stdout, stderr = Open3.popen3(command)

    output = stdout.readlines.collect(&:strip)
    errors = stderr.readlines.collect(&:strip)

    logger.debug { "GitoliteHook: Output from git:" }
    logger.debug { "GitoliteHook:  * STDOUT: #{output}"}
    logger.debug { "GitoliteHook:  * STDERR: #{errors}"}
  end

  def update_repository(repository)
    origin = Setting.plugin_redmine_gitolite['developerBaseUrls'].lines.first
    origin = origin.gsub("%{name}", repository.project.identifier)
    exec("git clone '#{origin}' '#{repository.url}' --bare") if !File.directory?(repo_location)
    exec("cd '#{repo_location}' && git fetch origin && git reset --soft refs/remotes/origin/master")
  end

  def get_identifier
    identifier = params[:project_id]
    # TODO: Can obtain 'oldrev', 'newrev', 'refname', 'user' in POST params for further action if needed.
    raise ActiveRecord::RecordNotFound, "Project identifier not specified" if identifier.nil?
    return identifier
  end

  def find_project
    identifier = get_identifier
    project = Project.find_by_identifier(identifier.downcase)
    raise ActiveRecord::RecordNotFound, "No project found with identifier '#{identifier}'" if project.nil?
    return project
  end

  def find_repository
    project = find_project
    repository = project.repository
    raise TypeError, "Project '#{project.to_s}' ('#{project.identifier}') has no repository" if repository.nil?
    raise TypeError, "Repository for project '#{project.to_s}' ('#{project.identifier}') is not a Git repository" unless repository.is_a?(Repository::Git)
    return repository
  end

end
