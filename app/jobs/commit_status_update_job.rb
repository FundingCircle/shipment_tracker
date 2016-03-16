# frozen_string_literal: true
class CommitStatusUpdateJob < ActiveJob::Base
  queue_as :default

  def perform(opts)
    CommitStatus.new.update(opts)
  end
end
