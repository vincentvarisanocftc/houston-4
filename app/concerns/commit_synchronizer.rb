module CommitSynchronizer
  
  
  def sync!
    repo.refresh!
    Houston.benchmark "Synchronize Commits" do
      existing_commits = project.commits.pluck(:sha)
      expected_commits = repo.all_commits
      
      create_missing_commits!   expected_commits - existing_commits
      flag_unreachable_commits! existing_commits - expected_commits
    end
  end
  
  
  def find_or_create_by_sha(sha)
    return nil if sha.nil?
    sha = sha.sha if sha.respond_to?(:sha)
    find_by_sha(sha) || create_missing_commit!(repo.native_commit(sha))
  rescue Houston::Adapters::VersionControl::CommitNotFound
    nil
  end
  
  
  def between(commit0, commit1)
    synchronize repo.commits_between(commit0, commit1)
  rescue Houston::Adapters::VersionControl::CommitNotFound
    []
  end
  
  
  def synchronize(native_commits)
    native_commits = native_commits.reject(&:nil?)
    return [] if native_commits.empty?
    
    Houston.benchmark("[commits.synchronize] synchronizing #{native_commits.length} commits") do
      shas = native_commits.map(&:sha)
      commits = where(sha: shas)
      
      native_commits.map do |native_commit|
        commit = commits.detect { |commit| commit.sha == native_commit.sha } ||
                 create_missing_commit!(native_commit)
        
        # There's no reason why this shouldn't be set,
        # but in order to reduce a bunch of useless hits
        # to the cache and a bunch of log output...
        commit.project = project
        commit
      end
    end
  end
  
  
private
  
  def create_missing_commits!(missing_commits)
    return if missing_commits.none?
    
    missing_commits.each do |sha|
      native_commit = repo.native_commit(sha)
      create_missing_commit!(native_commit) if native_commit
    end
    
    Rails.logger.info "[commits:sync] #{missing_commits.length} new commits for #{project.name}"
  end
  
  def create_missing_commit!(native_commit)
    return nil if native_commit.nil? # <-- can be a null object
    create!(attributes_from_native_commit(native_commit))
  rescue
    find_by_sha(native_commit.sha) || raise
  end
  
  def flag_unreachable_commits!(unreachable_commits)
    return if unreachable_commits.none?
    
    project.commits.where(sha: unreachable_commits).update_all(unreachable: true)
    
    Rails.logger.info "[commits:sync] #{unreachable_commits.length} unreachable commits for #{project.name}"
  end
  
  def repo
    project.repo
  end
  
  def project
    proxy_association.owner
  end
  
end
