# frozen_string_literal: true
require 'rails_helper'

RSpec.describe ReleasedTicketDecorator do
  subject(:decorator) { ReleasedTicketDecorator.new(released_ticket) }

  let(:released_ticket) { ReleasedTicket.new(deploys: deploys_hash) }

  let!(:commits) {
    [
      GitCommit.new(id: 'abc', message: 'new commit on master', time: time - 1.hour, parent_ids: ['def']),
      GitCommit.new(id: 'def', message: 'merge commit', time: time - 2.hours, parent_ids: %w(ghi xyz)),
      GitCommit.new(id: 'ghi', message: 'first commit on master branch', time: time - 3.hours),
    ]
  }

  let(:time) { Time.current }

  let(:deploys) {
    [
      Deploy.new(version: 'abc', app_name: 'app1', event_created_at: time - 30.minutes, deployed_by: 'user1'),
      Deploy.new(version: 'def', app_name: 'app2', event_created_at: time - 1.hour, deployed_by: 'user2'),
      Deploy.new(version: 'ghi', app_name: 'app2', event_created_at: time - 2.hours, deployed_by: 'user3'),
    ]
  }

  let(:deploys_hash) do
    deploys.map do |deploy|
      {
        'app' => deploy.app_name,
        'deployed_at' => deploy.event_created_at,
        'deployed_by' => deploy.deployed_by,
        'version' => deploy.version,
      }
    end
  end

  let(:deployed_commits) { commits.map { |commit| GitCommitWithDeploys.new(commit, deploys: deploys) } }

  let(:repository_loader) { instance_double(GitRepositoryLoader) }
  let(:repository) { instance_double(GitRepository) }

  before do
    allow(GitRepositoryLoader).to receive(:from_rails_config).and_return(repository_loader)
    allow(repository_loader).to receive(:load).and_return(repository)

    commits.each do |commit|
      allow(repository).to receive(:commit_for_version).with(commit.id).and_return(commit)
    end
  end

  it 'returns an array of deployed commits' do
    results = decorator.deployed_commits
    expect(results.map(&:id)).to eq(deployed_commits.map(&:id))
    expect(results.map(&:deploys).flatten).to eq(deploys)
  end
end
