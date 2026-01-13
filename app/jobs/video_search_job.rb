class VideoSearchJob < ApplicationJob
  queue_as :default

  def perform(*args)
    puts "Performing video search"
    sleep 10
    puts "Video search done"
  end
end
