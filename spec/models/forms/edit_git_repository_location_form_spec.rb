# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Forms::EditGitRepositoryLocationForm do
  def form_for(form_data = {}, options = {})
    repo = options.fetch(:repo, FactoryGirl.create(:git_repository_location))
    current_user = options.fetch('current_user', double('User', email: 'test@test.com'))

    described_class.new(repo: repo, params: form_data, current_user: current_user)
  end

  describe 'validation' do
    describe 'for repo_owners' do
      it 'could be blank' do
        expect(form_for(repo_owners: '')).to be_valid
        expect(form_for(repo_owners: nil)).to be_valid
      end

      describe 'a signle repo owner' do
        it 'expects an email or a name with email' do
          expect(form_for(repo_owners: 'test@example.com')).to be_valid
          expect(form_for(repo_owners: 'Test Example<test@example.com>')).to be_valid
        end

        it 'will fail if the provided value is neither an email nor a name with email' do
          ['test', 'test test@example.com'].each do |example|
            form = form_for(repo_owners: example)

            expect(form).not_to be_valid
            expect(form.errors[:repo_owners]).to be_present
          end
        end
      end

      it 'works with a list of repo owners separated by a new line or comma' do
        [
          "test@example.com\nTest Example <test@example.com>",
          "\n\nTest <test@example.com>  \n\n\nTest Example <test2@example.com>  \n\n\n",
          "Test <test@example.com>, Test Example <test2@example.com>\nTest Example <test3@example.com>",
        ].each do |data|
          expect(form_for(repo_owners: data)).to be_valid
        end
      end
    end
  end

  describe '#call' do
    it 'will generate a repo ownership event' do
      repo = FactoryGirl.create(:git_repository_location, name: 'my-app')
      current_user = double('User', email: 'test@test.com')
      input_data = "test@example.com, test3@example.com \n\n\nTest Example <test2@example.com>  \n\n\n"

      form = form_for({ repo_owners: input_data }, repo: repo, current_user: current_user)

      expect(Events::RepoOwnershipEvent).to(
        receive(:create!).with(
          details: {
            app_name: 'my-app',
            repo_owners: 'test@example.com, test3@example.com, Test Example <test2@example.com>',
            email: 'test@test.com',
          },
        ),
      )

      form.call
    end
  end
end
