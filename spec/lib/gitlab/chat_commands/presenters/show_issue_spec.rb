require 'spec_helper'

describe Gitlab::ChatCommands::Presenters::ShowIssue do
  let(:project) { create(:empty_project) }
  let(:issue) { create(:issue, project: project) }
  let(:attachment) { subject[:attachments].first }

  subject { described_class.new(issue).present }

  it { is_expected.to be_a(Hash) }

  it 'shows the issue' do
    expect(subject[:response_type]).to be(:in_channel)
    expect(subject).to have_key(:attachments)
    expect(attachment[:title]).to start_with(issue.title)
  end

  context 'with upvotes' do
    before do
      create(:award_emoji, :upvote, awardable: issue)
    end

    it 'shows the upvote count' do
      expect(attachment[:text]).to start_with("**Open** · :+1: 1")
    end
  end
end
