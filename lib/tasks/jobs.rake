# frozen_string_literal: true

require 'honeybadger'

namespace :jobs do
  def shutdown(task)
    warn "Terminating rake task #{task}..."
    @shutdown = true
  end

  desc 'Reset and recreate event snapshots (new events received during execution are not snapshotted)'
  task recreate_snapshots: :environment do
    Rails.logger.info 'Running recreate_snapshots'

    Repositories::Updater.from_rails_config.recreate

    Rails.logger.info 'Completed recreate_snapshots'
  end

  desc 'Continuously updates event cache'
  task update_events_loop: :environment do |t|
    Signal.trap('TERM') do
      shutdown(t)
    end

    Signal.trap('INT') do
      shutdown(t)
    end

    Rails.logger.info "Starting #{t}"
    Rails.logger.tagged(t) do
      until @shutdown
        start_time = Time.current

        from_event_id = Snapshots::EventCount.global_event_pointer

        Repositories::Updater.from_rails_config.run

        last_event_id = Snapshots::EventCount.global_event_pointer

        num_events = Events::BaseEvent.where('id > ?', from_event_id).where('id <= ?', last_event_id).count

        end_time = Time.current
        Rails.logger.info "Applied #{num_events} events in #{end_time - start_time} seconds"

        sleep 5 unless @shutdown
      end
    end
  end

  desc 'Continuously updates the local git repositories'
  task update_git_loop: :environment do |t|
    Signal.trap('TERM') do
      shutdown(t)
    end

    Signal.trap('INT') do
      shutdown(t)
    end

    Rails.logger.info "Starting #{t}"
    loader = GitRepositoryLoader.from_rails_config
    repos_hash_changed = GitRepositoryLocation.app_remote_head_hash
    repos_hash_before = repos_hash_changed.to_h.dup

    until @shutdown
      total = repos_hash_changed.size
      Rails.logger.debug "Updating #{total} git repositories"
      start_time = Time.current

      num_threads = [1, [Rails.configuration.git_worker_max_threads, total].min].max
      groups = repos_hash_changed.keys.in_groups(num_threads)
      groups.each.with_index(1).map { |group, thread_num|
        Thread.new do
          group.compact!
          group.each.with_index(1) do |app_name, index|
            break if @shutdown

            Rails.logger.tagged("[thread #{thread_num}] #{app_name} (#{index}/#{group.size})") do
              begin
                loader.load(app_name, update_repo: true)
              rescue StandardError => error
                Honeybadger.notify(
                  error,
                  context: {
                    app_name: app_name,
                    remote_head: repos_hash_changed[app_name],
                  },
                )
              end
            end
          end
        end
      }.each(&:join)
      unless repos_hash_changed.empty?
        Rails.logger.info "Updated #{total} git repositories in #{Time.current - start_time} seconds"
      end

      repos_hash_after = GitRepositoryLocation.app_remote_head_hash.to_h
      repos_hash_changed = repos_hash_after.reject { |name, remote_head|
        remote_head == repos_hash_before[name]
      }
      repos_hash_before = repos_hash_after.dup

      sleep Rails.configuration.git_worker_interval_seconds unless @shutdown
    end
  end
end
