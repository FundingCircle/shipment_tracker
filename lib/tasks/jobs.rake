namespace :jobs do
  def already_running?(pid_path)
    pid = File.read(pid_path)
    Process.kill(0, Integer(pid))
    true
  rescue Errno::ENOENT, Errno::ESRCH
    # no such file or pid
    false
  end

  def manage_pid(pid_path)
    fail "Pid file with running process detected, aborting (#{pid_path})" if already_running?(pid_path)
    puts "Writing pid file to #{pid_path}"
    File.open(pid_path, 'w+') do |f|
      f.write Process.pid
    end
    at_exit do
      File.delete(pid_path)
    end
  end

  def pid_path_for(name)
    require 'tmpdir'
    File.expand_path("#{name}.pid", Dir.tmpdir)
  end

  desc 'Update event cache'
  task update_events: :environment do
    manage_pid pid_path_for('jobs_update_events')

    puts "[#{Time.current}] Running update_events"
    Repositories::Updater.from_rails_config.run
    puts "[#{Time.current}] Completed update_events"
  end

  desc 'Continuously updates event cache'
  task update_events_loop: :environment do
    Signal.trap('TERM') do
      warn 'Terminating rake task jobs:update_events_loop...'
      @shutdown = true
    end

    loop do
      break if @shutdown
      start_time = Time.current
      puts "[#{start_time}] Running update_events"
      lowest_event_id = Snapshots::EventCount.all.min_by(&:event_id).try(:event_id).to_i

      Repositories::Updater.from_rails_config.run

      end_time = Time.current
      num_events = Events::BaseEvent.where('id > ?', lowest_event_id).count
      puts "[#{end_time}] Cached #{num_events} events in #{end_time - start_time} seconds"
      break if @shutdown
      sleep 5
    end
  end

  desc 'Continuously updates the local git repositories'
  task update_git_loop: :environment do
    manage_pid pid_path_for('update_git_loop')

    Signal.trap('TERM') do
      warn 'Terminating rake task jobs:update_git_loop...'
      @shutdown = true
    end

    loader = GitRepositoryLoader.from_rails_config

    loop do
      start_time = Time.current
      puts "[#{start_time}] Updating all git repositories"

      app_names = GitRepositoryLocation.pluck(:name)
      app_names.in_groups(4).map { |group|
        Thread.new do # Limited to 4 threads to avoid running out of memory.
          group.compact.each do |app_name|
            break if @shutdown
            loader.load(app_name, update_repo: true)
          end
        end
      }.each(&:join)

      end_time = Time.current
      puts "[#{end_time}] Updated #{app_names.size} repositories in #{end_time - start_time} seconds"
      sleep 5
    end
  end
end
