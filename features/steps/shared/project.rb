module SharedProject
  include Spinach::DSL

  # Create a project without caring about what it's called
  step "I own a project" do
    @project = create(:project, :repository, namespace: @user.namespace)
    @project.team << [@user, :master]
  end

  step "I own a project in some group namespace" do
    @group = create(:group, name: 'some group')
    @project = create(:project, namespace: @group)
    @project.team << [@user, :master]
  end

  step "project exists in some group namespace" do
    @group = create(:group, name: 'some group')
    @project = create(:project, :repository, namespace: @group, public_builds: false)
  end

  # Create a specific project called "Shop"
  step 'I own project "Shop"' do
    @project = Project.find_by(name: "Shop")
    @project ||= create(:project, :repository, name: "Shop", namespace: @user.namespace)
    @project.team << [@user, :master]
  end

  step 'I disable snippets in project' do
    @project.snippets_enabled = false
    @project.save
  end

  step 'I disable issues and merge requests in project' do
    @project.issues_enabled = false
    @project.merge_requests_enabled = false
    @project.save
  end

  # Add another user to project "Shop"
  step 'I add a user to project "Shop"' do
    @project = Project.find_by(name: "Shop")
    other_user = create(:user, name: 'Alpha')
    @project.team << [other_user, :master]
  end

  # Create another specific project called "Forum"
  step 'I own project "Forum"' do
    @project = Project.find_by(name: "Forum")
    @project ||= create(:project, :repository, name: "Forum", namespace: @user.namespace, path: 'forum_project')
    @project.build_project_feature
    @project.project_feature.save
    @project.team << [@user, :master]
  end

  # Create an empty project without caring about the name
  step 'I own an empty project' do
    @project = create(:empty_project,
                      name: 'Empty Project', namespace: @user.namespace)
    @project.team << [@user, :master]
  end

  step 'I visit my empty project page' do
    project = Project.find_by(name: 'Empty Project')
    visit namespace_project_path(project.namespace, project)
  end

  step 'I visit project "Shop" activity page' do
    project = Project.find_by(name: 'Shop')
    visit namespace_project_path(project.namespace, project)
  end

  step 'project "Shop" has push event' do
    @project = Project.find_by(name: "Shop")

    data = {
      before: Gitlab::Git::BLANK_SHA,
      after: "6d394385cf567f80a8fd85055db1ab4c5295806f",
      ref: "refs/heads/fix",
      user_id: @user.id,
      user_name: @user.name,
      repository: {
        name: @project.name,
        url: "localhost/rubinius",
        description: "",
        homepage: "localhost/rubinius",
        private: true
      }
    }

    @event = Event.create(
      project: @project,
      action: Event::PUSHED,
      data: data,
      author_id: @user.id
    )
  end

  step 'I should see project "Shop" activity feed' do
    project = Project.find_by(name: "Shop")
    expect(page).to have_content "#{@user.name} pushed new branch fix at #{project.name_with_namespace}"
  end

  step 'I should see project settings' do
    expect(current_path).to eq edit_namespace_project_path(@project.namespace, @project)
    expect(page).to have_content("Project name")
    expect(page).to have_content("Sharing & Permissions")
  end

  def current_project
    @project ||= Project.first
  end

  # ----------------------------------------
  # Project permissions
  # ----------------------------------------

  step 'I am member of a project with a guest role' do
    @project.team << [@user, Gitlab::Access::GUEST]
  end

  step 'I am member of a project with a reporter role' do
    @project.team << [@user, Gitlab::Access::REPORTER]
  end

  # ----------------------------------------
  # Visibility of archived project
  # ----------------------------------------

  step 'archived project "Archive"' do
    create(:project, :archived, :public, :repository, name: 'Archive')
  end

  step 'I should not see project "Archive"' do
    project = Project.find_by(name: "Archive")
    expect(page).not_to have_content project.name_with_namespace
  end

  step 'I should see project "Archive"' do
    project = Project.find_by(name: "Archive")
    expect(page).to have_content project.name_with_namespace
  end

  step 'project "Archive" has comments' do
    project = Project.find_by(name: "Archive")
    2.times { create(:note_on_issue, project: project) }
  end

  # ----------------------------------------
  # Visibility level
  # ----------------------------------------

  step 'private project "Enterprise"' do
    create(:project, :private, :repository, name: 'Enterprise')
  end

  step 'I should see project "Enterprise"' do
    expect(page).to have_content "Enterprise"
  end

  step 'I should not see project "Enterprise"' do
    expect(page).not_to have_content "Enterprise"
  end

  step 'internal project "Internal"' do
    create(:project, :internal, :repository, name: 'Internal')
  end

  step 'I should see project "Internal"' do
    page.within '.js-projects-list-holder' do
      expect(page).to have_content "Internal"
    end
  end

  step 'I should not see project "Internal"' do
    page.within '.js-projects-list-holder' do
      expect(page).not_to have_content "Internal"
    end
  end

  step 'public project "Community"' do
    create(:project, :public, :repository, name: 'Community')
  end

  step 'I should see project "Community"' do
    expect(page).to have_content "Community"
  end

  step 'I should not see project "Community"' do
    expect(page).not_to have_content "Community"
  end

  step '"John Doe" owns private project "Enterprise"' do
    user_owns_project(
      user_name: 'John Doe',
      project_name: 'Enterprise'
    )
  end

  step '"Mary Jane" owns private project "Enterprise"' do
    user_owns_project(
      user_name: 'Mary Jane',
      project_name: 'Enterprise'
    )
  end

  step '"John Doe" owns internal project "Internal"' do
    user_owns_project(
      user_name: 'John Doe',
      project_name: 'Internal',
      visibility: :internal
    )
  end

  step '"John Doe" owns public project "Community"' do
    user_owns_project(
      user_name: 'John Doe',
      project_name: 'Community',
      visibility: :public
    )
  end

  step 'public empty project "Empty Public Project"' do
    create :project_empty_repo, :public, name: "Empty Public Project"
  end

  step 'project "Community" has comments' do
    project = Project.find_by(name: "Community")
    2.times { create(:note_on_issue, project: project) }
  end

  step 'trending projects are refreshed' do
    TrendingProject.refresh!
  end

  step 'project "Shop" has labels: "bug", "feature", "enhancement"' do
    project = Project.find_by(name: "Shop")
    create(:label, project: project, title: 'bug')
    create(:label, project: project, title: 'feature')
    create(:label, project: project, title: 'enhancement')
  end

  step 'project "Shop" has issue: "bug report"' do
    project = Project.find_by(name: "Shop")
    create(:issue, project: project, title: "bug report")
  end

  step 'project "Shop" has CI enabled' do
    project = Project.find_by(name: "Shop")
    project.enable_ci
  end

  step 'project "Shop" has CI build' do
    project = Project.find_by(name: "Shop")
    pipeline = create :ci_pipeline, project: project, sha: project.commit.sha, ref: 'master'
    pipeline.skip
  end

  step 'I should see last commit with CI status' do
    page.within ".project-last-commit" do
      expect(page).to have_content(project.commit.sha[0..6])
      expect(page).to have_content("skipped")
    end
  end

  step 'The project is internal' do
    @project.update(visibility_level: Gitlab::VisibilityLevel::INTERNAL)
  end

  step 'public access for builds is enabled' do
    @project.update(public_builds: true)
  end

  step 'public access for builds is disabled' do
    @project.update(public_builds: false)
  end

  step 'project "Shop" has a "Bugfix MR" merge request open' do
    create(:merge_request, title: "Bugfix MR", target_project: project, source_project: project, author: project.users.first)
  end

  def user_owns_project(user_name:, project_name:, visibility: :private)
    user = user_exists(user_name, username: user_name.gsub(/\s/, '').underscore)
    project = Project.find_by(name: project_name)
    project ||= create(:empty_project, visibility, name: project_name, namespace: user.namespace)
    project.team << [user, :master]
  end
end
