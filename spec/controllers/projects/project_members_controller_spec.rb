require('spec_helper')

describe Projects::ProjectMembersController do
  let(:user) { create(:user) }
  let(:project) { create(:empty_project, :public, :access_requestable) }

  describe 'GET index' do
    it 'should have the settings/members address with a 302 status code' do
      get :index, namespace_id: project.namespace, project_id: project

      expect(response).to have_http_status(302)
      expect(response.location).to include namespace_project_settings_members_path(project.namespace, project)
    end
  end

  describe 'POST create' do
    let(:project_user) { create(:user) }

    before { sign_in(user) }

    context 'when user does not have enough rights' do
      before { project.team << [user, :developer] }

      it 'returns 404' do
        post :create, namespace_id: project.namespace,
                      project_id: project,
                      user_ids: project_user.id,
                      access_level: Gitlab::Access::GUEST

        expect(response).to have_http_status(404)
        expect(project.users).not_to include project_user
      end
    end

    context 'when user has enough rights' do
      before { project.team << [user, :master] }

      it 'adds user to members' do
        expect_any_instance_of(Members::CreateService).to receive(:execute).and_return(true)

        post :create, namespace_id: project.namespace,
                      project_id: project,
                      user_ids: project_user.id,
                      access_level: Gitlab::Access::GUEST

        expect(response).to set_flash.to 'Users were successfully added.'
        expect(response).to redirect_to(namespace_project_settings_members_path(project.namespace, project))
      end

      it 'adds no user to members' do
        expect_any_instance_of(Members::CreateService).to receive(:execute).and_return(false)

        post :create, namespace_id: project.namespace,
                      project_id: project,
                      user_ids: '',
                      access_level: Gitlab::Access::GUEST

        expect(response).to set_flash.to 'No users specified.'
        expect(response).to redirect_to(namespace_project_settings_members_path(project.namespace, project))
      end
    end
  end

  describe 'DELETE destroy' do
    let(:member) { create(:project_member, :developer, project: project) }

    before { sign_in(user) }

    context 'when member is not found' do
      it 'returns 404' do
        delete :destroy, namespace_id: project.namespace,
                         project_id: project,
                         id: 42

        expect(response).to have_http_status(404)
      end
    end

    context 'when member is found' do
      context 'when user does not have enough rights' do
        before { project.team << [user, :developer] }

        it 'returns 404' do
          delete :destroy, namespace_id: project.namespace,
                           project_id: project,
                           id: member

          expect(response).to have_http_status(404)
          expect(project.members).to include member
        end
      end

      context 'when user has enough rights' do
        before { project.team << [user, :master] }

        it '[HTML] removes user from members' do
          delete :destroy, namespace_id: project.namespace,
                           project_id: project,
                           id: member

          expect(response).to redirect_to(
            namespace_project_settings_members_path(project.namespace, project)
          )
          expect(project.members).not_to include member
        end

        it '[JS] removes user from members' do
          xhr :delete, :destroy, namespace_id: project.namespace,
                                 project_id: project,
                                 id: member

          expect(response).to be_success
          expect(project.members).not_to include member
        end
      end
    end
  end

  describe 'DELETE leave' do
    before { sign_in(user) }

    context 'when member is not found' do
      it 'returns 404' do
        delete :leave, namespace_id: project.namespace,
                       project_id: project

        expect(response).to have_http_status(404)
      end
    end

    context 'when member is found' do
      context 'and is not an owner' do
        before { project.team << [user, :developer] }

        it 'removes user from members' do
          delete :leave, namespace_id: project.namespace,
                         project_id: project

          expect(response).to set_flash.to "You left the \"#{project.human_name}\" project."
          expect(response).to redirect_to(dashboard_projects_path)
          expect(project.users).not_to include user
        end
      end

      context 'and is an owner' do
        let(:project) { create(:empty_project, namespace: user.namespace) }

        before { project.team << [user, :master] }

        it 'cannot remove himself from the project' do
          delete :leave, namespace_id: project.namespace,
                         project_id: project

          expect(response).to have_http_status(403)
        end
      end

      context 'and is a requester' do
        before { project.request_access(user) }

        it 'removes user from members' do
          delete :leave, namespace_id: project.namespace,
                         project_id: project

          expect(response).to set_flash.to 'Your access request to the project has been withdrawn.'
          expect(response).to redirect_to(namespace_project_path(project.namespace, project))
          expect(project.requesters).to be_empty
          expect(project.users).not_to include user
        end
      end
    end
  end

  describe 'POST request_access' do
    before { sign_in(user) }

    it 'creates a new ProjectMember that is not a team member' do
      post :request_access, namespace_id: project.namespace,
                            project_id: project

      expect(response).to set_flash.to 'Your request for access has been queued for review.'
      expect(response).to redirect_to(
        namespace_project_path(project.namespace, project)
      )
      expect(project.requesters.exists?(user_id: user)).to be_truthy
      expect(project.users).not_to include user
    end
  end

  describe 'POST approve' do
    let(:member) { create(:project_member, :access_request, project: project) }

    before { sign_in(user) }

    context 'when member is not found' do
      it 'returns 404' do
        post :approve_access_request, namespace_id: project.namespace,
                                      project_id: project,
                                      id: 42

        expect(response).to have_http_status(404)
      end
    end

    context 'when member is found' do
      context 'when user does not have enough rights' do
        before { project.team << [user, :developer] }

        it 'returns 404' do
          post :approve_access_request, namespace_id: project.namespace,
                                        project_id: project,
                                        id: member

          expect(response).to have_http_status(404)
          expect(project.members).not_to include member
        end
      end

      context 'when user has enough rights' do
        before { project.team << [user, :master] }

        it 'adds user to members' do
          post :approve_access_request, namespace_id: project.namespace,
                                        project_id: project,
                                        id: member

          expect(response).to redirect_to(
            namespace_project_settings_members_path(project.namespace, project)
          )
          expect(project.members).to include member
        end
      end
    end
  end

  describe 'POST apply_import' do
    let(:another_project) { create(:empty_project, :private) }
    let(:member) { create(:user) }

    before do
      project.team << [user, :master]
      another_project.team << [member, :guest]
      sign_in(user)
    end

    shared_context 'import applied' do
      before do
        post(:apply_import, namespace_id: project.namespace,
                            project_id: project,
                            source_project_id: another_project.id)
      end
    end

    context 'when user can access source project members' do
      before { another_project.team << [user, :guest] }
      include_context 'import applied'

      it 'imports source project members' do
        expect(project.team_members).to include member
        expect(response).to set_flash.to 'Successfully imported'
        expect(response).to redirect_to(
          namespace_project_settings_members_path(project.namespace, project)
        )
      end
    end

    context 'when user is not member of a source project' do
      include_context 'import applied'

      it 'does not import team members' do
        expect(project.team_members).not_to include member
      end

      it 'responds with not found' do
        expect(response.status).to eq 404
      end
    end
  end

  describe 'POST create' do
    let(:stranger) { create(:user) }

    context 'when creating owner' do
      before do
        project.team << [user, :master]
        sign_in(user)
      end

      it 'does not create a member' do
        expect do
          post :create, user_ids: stranger.id,
                        namespace_id: project.namespace,
                        access_level: Member::OWNER,
                        project_id: project
        end.to change { project.members.count }.by(0)
      end
    end

    context 'when create master' do
      before do
        project.team << [user, :master]
        sign_in(user)
      end

      it 'creates a member' do
        expect do
          post :create, user_ids: stranger.id,
                        namespace_id: project.namespace,
                        access_level: Member::MASTER,
                        project_id: project
        end.to change { project.members.count }.by(1)
      end
    end
  end
end
