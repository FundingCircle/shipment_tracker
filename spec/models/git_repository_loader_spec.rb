require 'rails_helper'
require 'git_repository_loader'
require 'support/git_test_repository'

RSpec.describe GitRepositoryLoader do
  let(:cache_dir) { Dir.mktmpdir }

  subject(:git_repository_loader) { GitRepositoryLoader.new(cache_dir: cache_dir) }

  describe '#load' do
    let(:test_git_repo) { Support::GitTestRepository.new }
    let(:repo_uri) { "file://#{test_git_repo.dir}" }
    let(:repo_name) { test_git_repo.dir.split('/').last }
    let(:remote_head) { test_git_repo.head_oid }

    let(:git_repository_location) {
      instance_double(
        GitRepositoryLocation,
        id: anything,
        name: repo_name,
        uri: repo_uri,
        remote_head: remote_head,
      )
    }

    before do
      test_git_repo.create_commit
      allow(GitRepositoryLocation).to receive(:find_by_name).and_return(git_repository_location)
    end

    context 'when updating repository' do
      it 'returns a GitRepository' do
        expect(git_repository_loader.load(repo_name, update_repo: true)).to be_a(GitRepository)
      end

      context 'when the repository location does not exist' do
        let(:git_repository_location) { nil }

        it 'raises a NotFound exception' do
          expect {
            git_repository_loader.load('missing-repo', update_repo: true)
          }.to raise_error(GitRepositoryLoader::NotFound)
        end
      end

      context 'when the repository has not been cloned yet' do
        it 'should clone it' do
          expect(Rugged::Repository).to receive(:clone_at).once

          git_repository_loader.load(repo_name, update_repo: true)
        end
      end

      context 'when the repository has already been cloned' do
        before do
          git_repository_loader.load(repo_name, update_repo: true)
        end

        context 'when the local copy is up-to-date' do
          it 'should do nothing' do
            expect(Rugged::Repository).to_not receive(:clone_at)
            expect_any_instance_of(Rugged::Repository).to_not receive(:fetch)

            git_repository_loader.load(repo_name, update_repo: true)
          end
        end

        context 'when the local copy is not up-to-date' do
          let(:remote_head) { 'newer-commit' }

          it 'should fetch the repository' do
            expect(Rugged::Repository).to_not receive(:clone_at)
            expect_any_instance_of(Rugged::Repository).to receive(:fetch).once

            git_repository_loader.load(repo_name, update_repo: true)
          end
        end

        context 'when the local copy HEAD points to a ref that does not exist' do
          before do
            allow_any_instance_of(Rugged::Repository).to receive(:head).and_raise(Rugged::ReferenceError)
          end

          it 'clones the repo instead of fetching it to continue the update' do
            expect(Rugged::Repository).to receive(:clone_at).once

            git_repository_loader.load(repo_name, update_repo: true)
          end
        end
      end

      context 'when the destination directory is not empty and is not a git repo' do
        before do
          path = repository_dir_name(git_repository_location)
          Dir.mkdir(path)
          File.open(File.join(path, 'foo.txt'), 'w') do |f| f.write('foo') end
        end

        after do
          path = repository_dir_name(git_repository_location)
          FileUtils.rm_rf(path)
        end

        it 'removes the destination directory before cloning' do
          expect(Rugged::Repository).to receive(:clone_at).once
          expect { git_repository_loader.load(repo_name, update_repo: true) }.not_to raise_error
        end
      end

      context 'with an HTTP URI' do
        let(:repo_uri) { 'http://example.com/repo.git' }

        it 'should not use credentials' do
          expect(Rugged::Repository).to receive(:clone_at) do |_uri, _dir, options|
            expect(options).to_not have_key(:credentials)
          end

          git_repository_loader.load('repo', update_repo: true)
        end
      end

      context 'with an SSH URI' do
        let(:repo_uri) { 'git@example.com:owner/repo.git' }
        let(:ssh_private_key) { 'PR1V4t3' }
        let(:ssh_public_key) { 'PU8L1C' }
        let(:ssh_user) { 'alice' }

        subject(:git_repository_loader) {
          GitRepositoryLoader.new(
            cache_dir: cache_dir,
            ssh_private_key: ssh_private_key,
            ssh_public_key: ssh_public_key,
            ssh_user: ssh_user,
          )
        }

        it 'uses the correct credentials' do
          private_key_file = nil
          public_key_file = nil

          expect(Rugged::Repository).to receive(:clone_at) do |uri, _directory, options|
            # This is a Rugged::Credentials object which is a C extension
            # We need to delve into the internals of this to check it is the correct credentials object\
            # that is being passed to the clone method
            credentials = options.fetch(:credentials)
            username = credentials.instance_variable_get(:@username)
            private_key_file = credentials.instance_variable_get(:@privatekey)
            public_key_file = credentials.instance_variable_get(:@publickey)

            expect(uri).to eq(repo_uri)

            expect(username).to eq(ssh_user)

            expect(File.read(private_key_file)).to eq(ssh_private_key + "\n")
            expect(File.stat(private_key_file)).to_not be_world_readable

            expect(File.read(public_key_file)).to eq(ssh_public_key + "\n")
            expect(File.stat(public_key_file)).to_not be_world_readable
          end

          git_repository_loader.load('repo', update_repo: true)

          expect(File.exist?(private_key_file)).to be(false), 'The privatekey file should be cleaned up'
          expect(File.exist?(public_key_file)).to be(false), 'The publickey file should be cleaned up'
        end

        context 'when ssh_private_key is missing' do
          let(:ssh_private_key) { nil }

          it 'raises an error' do
            expect {
              git_repository_loader.load('repo', update_repo: true)
            }.to raise_error('ssh_private_key not set')
          end
        end

        context 'when ssh_public_key is missing' do
          let(:ssh_public_key) { nil }

          it 'raises an error' do
            expect {
              git_repository_loader.load('repo', update_repo: true)
            }.to raise_error('ssh_public_key not set')
          end
        end

        context 'when ssh_user is missing' do
          let(:ssh_user) { nil }

          it 'raises an error' do
            expect {
              git_repository_loader.load('repo', update_repo: true)
            }.to raise_error('ssh_user not set')
          end
        end
      end
    end

    context 'when not updating repository' do
      before do
        allow(Rugged::Repository).to receive(:new)
      end

      it 'returns a GitRepository' do
        expect(git_repository_loader.load(repo_name, update_repo: false)).to be_a(GitRepository)
      end

      it 'does not fetch the repo' do
        expect_any_instance_of(Rugged::Repository).to_not receive(:fetch)

        git_repository_loader.load('repo', update_repo: false)
      end

      it 'does not clone the repo' do
        expect(Rugged::Repository).to_not receive(:clone_at)

        git_repository_loader.load('repo', update_repo: false)
      end

      context 'when the location given is not valid' do
        before do
          allow(Rugged::Repository).to receive(:new) { fail Rugged::RepositoryError }
        end

        it 'raised a BadLocation error' do
          expect {
            git_repository_loader.load('repo', update_repo: false)
          }.to raise_error(
            GitRepositoryLoader::BadLocation,
            "Invalid directory location for repository: #{git_repository_location.name}",
          )
        end
      end
    end
  end

  def repository_dir_name(git_repository_location)
    File.join(cache_dir, "#{git_repository_location.id}-#{git_repository_location.name}")
  end
end
