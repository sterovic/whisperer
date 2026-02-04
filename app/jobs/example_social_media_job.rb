class ExampleSocialMediaJob < ApplicationJob
  queue_as :default

  # Optional: Configure job behavior
  # retry_on StandardError, wait: 5.seconds, attempts: 3

  def perform(user_id, options = {})
    @user = User.find(user_id)
    @job_id = job_id
    @total_steps = 5

    begin
      # Step 1: Initialize
      broadcast_progress(1, "Initializing job...")
      sleep 1 # Simulating work

      # Step 2: Fetch data from external API
      broadcast_progress(2, "Fetching data from social media API...")
      data = fetch_social_media_data
      sleep 1

      # Step 3: Process and transform data
      broadcast_progress(3, "Processing fetched data...")
      processed_data = process_data(data)
      sleep 1

      # Step 4: Store in database (JSONB column)
      broadcast_progress(4, "Storing data in database...")
      store_data(processed_data)
      sleep 1

      # Step 5: Complete
      broadcast_progress(5, "Job completed successfully!")
      broadcast_completion(success: true, message: "Successfully processed social media data")

    rescue StandardError => e
      # Handle errors and notify user
      broadcast_error(e.message)
      raise # Re-raise to let GoodJob handle retries
    end
  end

  private

  def fetch_social_media_data
    # Simulate API call
    # In real implementation, use HTTParty, Faraday, or similar
    {
      posts: [
        { id: 1, content: "Example post 1", likes: 100 },
        { id: 2, content: "Example post 2", likes: 250 }
      ],
      followers: 1500,
      engagement_rate: 4.5
    }
  end

  def process_data(data)
    # Transform/clean the data as needed
    {
      posts: data[:posts],
      statistics: {
        followers: data[:followers],
        engagement_rate: data[:engagement_rate],
        total_posts: data[:posts].count
      },
      fetched_at: Time.current
    }
  end

  def store_data(data)
    # Store in a JSONB column
    # Assumes you have a model with a jsonb column, e.g.:
    # create_table :social_media_caches do |t|
    #   t.references :user, null: false
    #   t.jsonb :data, default: {}
    #   t.string :source
    #   t.timestamps
    # end

    # Example:
    # SocialMediaCache.find_or_create_by(user: @user, source: 'example').update(data: data)

    # For now, just log it
    Rails.logger.info "Would store data: #{data.inspect}"
  end

  def broadcast_progress(step, message)
    progress_percentage = (step.to_f / @total_steps * 100).to_i

    Turbo::StreamsChannel.broadcast_replace_to(
      "job_progress_#{@user.id}",
      target: "job_#{@job_id}",
      partial: "jobs/progress",
      locals: {
        job_id: @job_id,
        message: message,
        percentage: progress_percentage,
        status: :running
      }
    )
  end

  def broadcast_completion(success:, message:)
    Turbo::StreamsChannel.broadcast_replace_to(
      "job_progress_#{@user.id}",
      target: "job_#{@job_id}",
      partial: "jobs/progress",
      locals: {
        job_id: @job_id,
        message: message,
        percentage: 100,
        status: success ? :completed : :failed
      }
    )
  end

  def broadcast_error(error_message)
    Turbo::StreamsChannel.broadcast_replace_to(
      "job_progress_#{@user.id}",
      target: "job_#{@job_id}",
      partial: "jobs/progress",
      locals: {
        job_id: @job_id,
        message: "Error: #{error_message}",
        percentage: 0,
        status: :failed
      }
    )
  end
end
