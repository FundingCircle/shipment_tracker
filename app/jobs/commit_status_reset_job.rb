# frozen_string_literal: true

require 'commit_status'

class CommitStatusResetJob < CommitStatusRetryableJob
  queue_as :default

  def perform(opts)
    CommitStatus.new(full_repo_name: opts[:full_repo_name], sha: opts[:sha]).reset
  end
end
