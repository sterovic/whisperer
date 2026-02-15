namespace :channels do
  desc "Backfill channels table from video raw_data and link videos"
  task backfill: :environment do
    videos_with_channel = Video.where("raw_data->>'channel_id' IS NOT NULL AND raw_data->>'channel_id' != ''")

    grouped = videos_with_channel.group_by { |v| [v.project_id, v.raw_data["channel_id"]] }

    puts "Found #{grouped.size} unique project/channel pairs across #{videos_with_channel.count} videos"

    grouped.each_with_index do |(key, videos), index|
      project_id, yt_channel_id = key
      project = Project.find(project_id)
      sample_video = videos.first

      channel = project.channels.find_or_initialize_by(youtube_channel_id: yt_channel_id)
      channel.name ||= sample_video.raw_data["channel_title"]
      channel.save!

      # Batch update videos to point to this channel
      Video.where(id: videos.map(&:id)).where(channel_id: nil).update_all(channel_id: channel.id)

      # Try to fetch metadata from YouTube API
      begin
        yt_channel = Yt::Channel.new(id: yt_channel_id)
        channel.update!(
          name: yt_channel.title,
          thumbnail_url: yt_channel.thumbnail_url,
          subscriber_count: yt_channel.subscriber_count,
          video_count: yt_channel.video_count,
          description: yt_channel.description
        )
      rescue => e
        puts "  Could not fetch metadata for #{yt_channel_id}: #{e.message}"
      end

      puts "[#{index + 1}/#{grouped.size}] #{channel.name || yt_channel_id} — #{videos.size} videos linked"
    end

    puts "Done! #{Channel.count} channels total."
  end
end
