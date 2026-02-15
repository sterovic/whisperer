Rails.application.configure do
  # Configure GoodJob as the ActiveJob backend
  config.active_job.queue_adapter = :good_job

  # GoodJob configuration
  config.good_job = {
    # Execution mode:
    # - :async - Execute jobs in separate threads within the web process (development)
    # - :external - Execute jobs in a separate worker process (production/Heroku)
    execution_mode: Rails.env.production? ? :external : :async,

    preserve_job_records: true,

    # Maximum number of threads for job execution in async mode
    max_threads: ENV.fetch("GOOD_JOB_MAX_THREADS", 3).to_i,

    # Poll interval for checking new jobs
    poll_interval: ENV.fetch("GOOD_JOB_POLL_INTERVAL", 10).to_i,

    # Enable cron scheduling
    enable_cron: true,

    # Cron jobs - these can be overridden from database records
    cron: {
      # Example cron job (commented out - define your jobs here or in the database)
      # example_job: {
      #   cron: "*/5 * * * *", # Every 5 minutes
      #   class: "ExampleJob",
      #   description: "Example scheduled job"
      # }
    },

    # Preserve finished jobs for debugging (set to 0 to delete immediately)
    cleanup_preserved_jobs_before_seconds_ago: 7.days.to_i,

    # Enable dashboard authentication (configure before enabling in routes)
    dashboard_default_locale: :en
  }
end
