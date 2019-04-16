# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RelinkTicketJob do
  let(:org_name) { 'acme'}
  let(:repo_name) { 'awesome-app'}
  let(:full_repo_name) { "#{org_name}/#{repo_name}" }
  let(:before_sha) { '123456789' }
  let(:after_sha) { '987654321' }
  let(:branch_without_ticket_key) { "km-some-feature" }
  let(:ticket_key) { 'MOB-123' }
  let(:branch_with_ticket_key) { "km-some-feature-#{ticket_key}" }
  let(:expected_url) { "https://localhost/feature_reviews?apps%5B#{repo_name}%5D=#{after_sha}" }
  
  describe '#perform' do
    context 'given a commit on master' do
      let(:args) do
        {
          full_repo_name: full_repo_name,
          before_sha: before_sha,
          after_sha: after_sha,
          branch_created: true,
          branch_name: 'master'
        }

        it 'should not link any tickets' do
          expect(JiraClient).not_to receive(:post_comment)
          subject.perform(args)
        end
      end
    end


    context 'given a push for a newly created branch with a ticket key in the branch name' do
      let(:args) do
        {
          full_repo_name: full_repo_name,
          before_sha: '123456789',
          after_sha: '987654321',
          branch_created: true,
          branch_name: branch_with_ticket_key
        }
      end

      it 'should link the correct ticket key' do
        expected_comment = "[Feature ready for review|#{expected_url}]"
        expect(JiraClient).to receive(:post_comment).with(ticket_key, expected_comment)
        subject.perform(args)
      end
    end
  end

  describe '#extract_ticket_key_from_branch_name' do
    context 'given a branch name that contains a JIRA ticket key' do
      it 'should find the ticket key' do
        extracted_key = subject.send(:extract_ticket_key_from_branch_name, branch_with_ticket_key)
        expect(extracted_key).to eq ticket_key
      end    
    end

    context 'given a branch name that does not contain a JIRA ticket key' do
      it 'should find the ticket key' do
        extracted_key = subject.send(:extract_ticket_key_from_branch_name, branch_without_ticket_key)
        expect(extracted_key).to eq nil
      end    
    end
  end

  describe '#url_for_repo_and_sha' do
    context 'given a valid repo name and sha' do
      it 'should return a valid feature release URL' do
        url = subject.send(:url_for_repo_and_sha, full_repo_name, after_sha)
        expect(url).to eq "https://localhost/feature_reviews?apps%5B#{repo_name}%5D=#{after_sha}"
      end 
    end
  end

  describe '#check_branch_for_ticket_and_link?' do
    context 'given a branch name with out a ticket key' do
      it 'should return true' do
        result = subject.send(:check_branch_for_ticket_and_link?, '', branch_without_ticket_key, '')
        expect(result).to eq true
      end 
    end
  end
end
