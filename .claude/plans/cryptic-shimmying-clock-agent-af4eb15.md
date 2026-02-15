# Implementation Plan: Channel Model as First-Class Entity

## Overview

Create a `Channel` model as the central entity for YouTube channels, build a channels index page with aggregated stats,
restructure the sidebar to promote channels to a top-level menu, move channel subscriptions out of Settings, extract the
subscribe form to its own page with richer UI, and create a rake task to backfill channels from existing video data.

---

## Phase 1: Database Foundation

### 1.1 Migration: Create `channels` table

**File to create:** `db/migrate/XXXXXX_create_channels.rb`

```ruby
class CreateChannels < ActiveRecord::Migration[8.0]
  def change
    create_table :channels do |t|
      t.string :youtube_channel_id, null: false
      t.string :name
      t.string :thumbnail_url
      t.integer :subscriber_count
      t.integer :video_count
      t.text :description
      t.string :custom_url
      t.references :project, null: false, foreign_key: true

      t.timestamps
    end

    add_index :channels, [:project_id, :youtube_channel_id], unique: true
    add_index :channels, :youtube_channel_id
  end
end
```

**Design rationale:** Mirrors the metadata fields already stored on `ChannelSubscription` (`channel_name`,
`channel_thumbnail_url`, `subscriber_count`, `video_count`) plus adds `description` and `custom_url` for richer display.
The unique compound index on `[project_id, youtube_channel_id]` matches the existing pattern used by videos (
`[youtube_id, project_id]`).

### 1.2 Migration: Add `channel_id` foreign key to `videos`

**File to create:** `db/migrate/XXXXXX_add_channel_id_to_videos.rb`

```ruby
class AddChannelIdToVideos < ActiveRecord::Migration[8.0]
  def change
    add_reference :videos, :channel, null: true, foreign_key: true
  end
end
```

**Why nullable:** Existing videos will not have a `channel_id` until the rake task runs. New videos will get it set by
`FetchVideoMetadataJob`.

---

## Phase 2: Channel Model & Associations

### 2.1 Create Channel model

**File to create:** `app/models/channel.rb`

```ruby
class Channel < ApplicationRecord
  belongs_to :project
  has_many :videos, dependent: :nullify

  validates :youtube_channel_id, presence: true
  validates :youtube_channel_id, uniqueness: { scope: :project_id }

  scope :with_stats, -> {
    left_joins(videos: :comments)
      .select(
        "channels.*",
        "COUNT(DISTINCT videos.id) AS local_video_count",
        "COUNT(CASE WHEN comments.parent_id IS NULL THEN comments.id END) AS total_comments_posted",
        "COUNT(CASE WHEN comments.parent_id IS NULL AND comments.status = 0 THEN 1 END) AS visible_comments_count",
        "COUNT(CASE WHEN comments.parent_id IS NULL AND comments.status = 1 THEN 1 END) AS hidden_comments_count",
        "COUNT(CASE WHEN comments.parent_id IS NULL AND comments.status = 2 THEN 1 END) AS removed_comments_count",
        "MIN(CASE WHEN comments.parent_id IS NULL THEN comments.rank END) AS best_comment_rank"
      )
      .group("channels.id")
  }

  def display_name
    name.presence || youtube_channel_id
  end

  def youtube_url
    "https://youtube.com/channel/#{youtube_channel_id}"
  end

  # Comment success rate: visible / total (excluding those with no comments)
  def comment_success_rate
    total = total_comments_posted.to_i
    return nil if total == 0
    (visible_comments_count.to_f / total * 100).round(1)
  end

  # Fetch and update metadata from YouTube API
  def fetch_metadata!
    yt_channel = Yt::Channel.new(id: youtube_channel_id)
    update!(
      name: yt_channel.title,
      thumbnail_url: yt_channel.thumbnail_url,
      subscriber_count: yt_channel.subscriber_count,
      video_count: yt_channel.video_count,
      description: yt_channel.description
    )
  rescue Yt::Errors::NoItems, Yt::Errors::Forbidden => e
    Rails.logger.warn "Could not fetch channel metadata for #{youtube_channel_id}: #{e.message}"
  end

  # Find or create from YouTube API data, then return
  def self.find_or_create_from_video!(project:, channel_id:, channel_title: nil)
    return nil if channel_id.blank?

    find_or_create_by!(project: project, youtube_channel_id: channel_id) do |channel|
      channel.name = channel_title
    end
  rescue ActiveRecord::RecordNotUnique
    find_by!(project: project, youtube_channel_id: channel_id)
  end
end
```

**Design notes:**

- `with_stats` scope follows the exact same aggregation pattern used in `VideosController#index` (left_joins + SELECT
  with CASE/COUNT/MIN + group).
- `find_or_create_from_video!` handles race conditions with `rescue RecordNotUnique`.
- `comment_success_rate` computes visible / total as a percentage -- same concept as the video status breakdown badges.
- `has_many :videos, dependent: :nullify` -- deleting a channel does not destroy its videos, just unlinks them.

### 2.2 Update Video model

**File to modify:** `app/models/video.rb`

Add the association:

```ruby
belongs_to :channel, optional: true
```

The `optional: true` is needed because existing videos will not have a `channel_id` until the rake task runs, and the
column is nullable.

### 2.3 Update Project model

**File to modify:** `app/models/project.rb`

Add the association:

```ruby
has_many :channels, dependent: :destroy
```

Place it near the other `has_many` declarations at the top of the class.

---

## Phase 3: Update Import Jobs to Create Channels

### 3.1 Update FetchVideoMetadataJob

**File to modify:** `app/jobs/fetch_video_metadata_job.rb`

After the `video.update!` call that stores `raw_data`, add channel find-or-create logic:

```ruby
# After video.update!(...)
if video.channel_id.nil?
  channel_id = yt_video.channel_id
  channel_title = yt_video.channel_title
  if channel_id.present?
    channel = Channel.find_or_create_from_video!(
      project: video.project,
      channel_id: channel_id,
      channel_title: channel_title
    )
    video.update_column(:channel_id, channel.id) if channel
  end
end
```

**Why `update_column`:** We already called `video.update!` for the metadata. Using `update_column` avoids triggering
callbacks/validations again and is a single lightweight SQL UPDATE.

**Why here and not elsewhere:** `FetchVideoMetadataJob` is the single point through which all video imports flow (both
`YouTubeVideoImportJob` and `ChannelFeedPollingJob` call it). Placing the channel creation here means every import path
is covered with no duplication.

---

## Phase 4: Channels Controller & Index Page

### 4.1 Create ChannelsController

**File to create:** `app/controllers/channels_controller.rb`

```ruby
class ChannelsController < ApplicationController
  before_action :authenticate_user!

  def index
    @channels = current_project.channels
                               .with_stats
                               .order(Arel.sql("COUNT(DISTINCT videos.id) DESC"))
  end

  private

  def current_project
    current_user.current_project
  end

  helper_method :current_project
end
```

**Pattern followed:** Same structure as `VideosController` and `CommentsController` --
`before_action :authenticate_user!`, private `current_project` helper, `helper_method` declaration.

### 4.2 Create Channels Index View

**File to create:** `app/views/channels/index.html.erb`

The page structure follows the existing patterns from `videos/index.html.erb` and `dashboard/_content.html.erb`:

1. **Breadcrumb** (Home > Channels) -- same pattern as videos index
2. **Page header** with title "Channels" and count
3. **Summary stats row** (4 cards in a grid) using the dashboard stats card pattern:
    - Total Channels
    - Total Videos (across channels)
    - Average Comment Success Rate
    - Best Comment Rank
4. **Channels table/card list** -- each channel row shows:
    - Thumbnail (rounded-full, same as subscriptions page)
    - Channel name (linked to YouTube)
    - Videos in DB count
    - Comments posted count
    - Success rate (visible/total as percentage, with color coding)
    - Best rank (badge)
    - YouTube subscriber count (human-readable)
    - YouTube video count

**Stats card markup** (follows dashboard pattern exactly):

```erb
<div class="bg-base-100 rounded-box border border-base-300 p-4">
  <div class="flex items-center gap-3">
    <div class="bg-primary/10 rounded-box p-3">
      <span class="iconify lucide--radio size-6 text-primary"></span>
    </div>
    <div>
      <p class="text-2xl font-bold"><%= @channels.length %></p>
      <p class="text-sm text-base-content/60">Channels</p>
    </div>
  </div>
</div>
```

**Channel row markup** reuses the card pattern from `settings/channel_subscriptions/index.html.erb` (thumbnail + info +
stats flex layout) but adds the aggregated comment stats columns.

---

## Phase 5: Move Channel Subscriptions Out of Settings

### 5.1 Create New Controller (Channels namespace)

**File to create:** `app/controllers/channels/subscriptions_controller.rb`

```ruby
module Channels
  class SubscriptionsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_project

    def index
      @channel_subscriptions = @project.channel_subscriptions.order(created_at: :desc)
    end

    def new
      @new_subscription = @project.channel_subscriptions.build
      @known_channels = load_known_channels
    end

    def create
      # ... identical logic to current Settings::ChannelSubscriptionsController#create
      # but redirect to channels_subscriptions_path instead of settings_channel_subscriptions_path
    end

    def destroy
      @subscription = @project.channel_subscriptions.find(params[:id])
      @subscription.destroy
      redirect_to channels_subscriptions_path, notice: "Channel subscription removed."
    end

    private

    def set_project
      @project = @current_project
      redirect_to dashboard_path, alert: "Please select a project first." unless @project
    end

    def load_known_channels
      already_subscribed = @project.channel_subscriptions.pluck(:channel_id)

      # NEW: Query Channel model instead of raw_data
      @project.channels
              .where.not(youtube_channel_id: already_subscribed)
              .order(Arel.sql("LOWER(COALESCE(name, youtube_channel_id))"))
    end
  end
end
```

**Key change in `load_known_channels`:** Instead of querying `raw_data->>'channel_id'` from videos (fragile JSON
queries), we now query the `Channel` model directly. This returns full `Channel` records with `thumbnail_url`,
`subscriber_count`, etc. -- enabling the richer card UI in the form.

### 5.2 Update Routes

**File to modify:** `config/routes.rb`

Remove from settings namespace:

```ruby
# REMOVE this line from the settings namespace:
# resources :channel_subscriptions, only: [:index, :create, :destroy]
```

Add new top-level channels routes:

```ruby
# Channels
resources :channels, only: [:index] do
  collection do
    # Nested under /channels but not a true nested resource
  end
end

namespace :channels do
  resources :subscriptions, only: [:index, :new, :create, :destroy]
end
```

This produces:

- `GET /channels` -> `channels#index` (channels index page)
- `GET /channels/subscriptions` -> `channels/subscriptions#index`
- `GET /channels/subscriptions/new` -> `channels/subscriptions#new`
- `POST /channels/subscriptions` -> `channels/subscriptions#create`
- `DELETE /channels/subscriptions/:id` -> `channels/subscriptions#destroy`

### 5.3 Delete Old Controller

**File to delete:** `app/controllers/settings/channel_subscriptions_controller.rb`

### 5.4 Reorganize Views

**Files to move/create:**

- `app/views/settings/channel_subscriptions/index.html.erb` -> DELETE (replaced)
- `app/views/channels/subscriptions/index.html.erb` -> CREATE (subscriptions list only, no form)
- `app/views/channels/subscriptions/new.html.erb` -> CREATE (subscribe form with rich channel cards)

---

## Phase 6: Views in Detail

### 6.1 Subscriptions Index (`channels/subscriptions/index.html.erb`)

This is the **existing subscriptions list view** but:

- Breadcrumb: Home > Channels > Subscriptions
- Remove the "Add Channel" form section (moved to `new` page)
- Add a button in the header: `<%= link_to new_channels_subscription_path, class: "btn btn-primary btn-sm gap-2" do %>`
  with a plus icon and "Subscribe" text
- Keep the subscribed channels list exactly as-is (thumbnail, status badge, stats, recent videos preview, delete action)

### 6.2 Subscribe Form (`channels/subscriptions/new.html.erb`)

This is the **extracted form** with enhanced UI:

**Breadcrumb:** Home > Channels > Subscriptions > Subscribe

**Known Channels section** -- instead of plain checkboxes, display Channel model records as cards:

```erb
<% @known_channels.each do |channel| %>
  <label class="flex items-center gap-3 cursor-pointer p-3 rounded-box border border-base-300
                hover:bg-base-200 transition-colors has-[:checked]:bg-primary/10
                has-[:checked]:border-primary">
    <input type="checkbox"
           name="channel_subscription[channel_ids][]"
           value="<%= channel.youtube_channel_id %>"
           class="checkbox checkbox-primary checkbox-sm" />
    <% if channel.thumbnail_url.present? %>
      <%= image_tag channel.thumbnail_url, class: "w-10 h-10 rounded-full object-cover", alt: channel.display_name %>
    <% else %>
      <div class="w-10 h-10 rounded-full bg-base-200 flex items-center justify-center">
        <span class="iconify lucide--youtube size-5 text-base-content/30"></span>
      </div>
    <% end %>
    <div class="flex-1 min-w-0">
      <p class="font-medium text-sm truncate"><%= channel.display_name %></p>
      <div class="flex items-center gap-2 text-xs text-base-content/50">
        <% if channel.subscriber_count.present? %>
          <span><%= number_to_human(channel.subscriber_count, precision: 1, significant: false) %> subs</span>
        <% end %>
        <% if channel.video_count.present? %>
          <span>&bull; <%= channel.video_count %> videos</span>
        <% end %>
      </div>
    </div>
  </label>
<% end %>
```

**Manual input section** and **Initial import limit** remain the same as the current form.

### 6.3 Channels Index (`channels/index.html.erb`)

Full page structure:

```
Breadcrumb: Home > Channels
Header: "Channels" + count + link to Subscriptions page

Stats Cards Row (grid-cols-4):
  - Total Channels (lucide--radio, primary)
  - Total Videos in DB (lucide--video, secondary)  
  - Avg Success Rate (lucide--target, success)
  - Best Rank (lucide--trophy, warning)

Channels Table:
  <table class="table table-sm">
    Columns: Thumbnail | Channel | Videos | Comments | Success Rate | Best Rank | YouTube Stats | Actions
    
    Each row:
    - 48x48 rounded-full thumbnail (or placeholder)
    - Channel name (linked to YouTube, truncated) + youtube_channel_id in mono text below
    - local_video_count (bold number)
    - total_comments_posted (bold number)
    - Success rate as percentage with color badge:
        >= 80%: badge-success
        >= 50%: badge-warning  
        < 50%: badge-error
        nil: "-"
    - best_comment_rank as "#N" badge or "-"
    - subscriber_count + video_count (human readable, smaller text)
    - Actions: View on YouTube (external link icon)

Empty state if no channels (same pattern as videos/subscriptions)
```

---

## Phase 7: Sidebar Update

### 7.1 Modify Sidebar

**File to modify:** `app/views/shared/_sidebar.html.erb`

**Add "Channels" collapsible menu** between the "Videos" collapsible and "Google Accounts" link. Uses the exact same
collapse pattern as Videos and Settings:

```erb
<% channels_active = controller_name == 'channels' || controller_path.start_with?('channels/') %>
<div class="group collapse <%= 'collapse-open' if channels_active %>">
  <input
    aria-label="Sidemenu item trigger"
    type="checkbox"
    class="peer"
    name="sidebar-menu-channels"
    <%= 'checked' if channels_active %> />
  <div class="collapse-title px-2.5 py-1.5">
    <span class="iconify lucide--radio size-4"></span>
    <span class="grow">Channels</span>
    <span class="iconify lucide--chevron-right arrow-icon size-3.5"></span>
  </div>
  <div class="collapse-content ms-6.5 !p-0">
    <div class="mt-0.5 space-y-0.5">
      <%= link_to channels_path, class: "menu-item #{controller_name == 'channels' && controller_path == 'channels' ? 'active' : ''}" do %>
        <span class="grow">All Channels</span>
      <% end %>
      <%= link_to channels_subscriptions_path, class: "menu-item #{controller_path == 'channels/subscriptions' ? 'active' : ''}" do %>
        <span class="grow">Subscriptions</span>
      <% end %>
    </div>
  </div>
</div>
```

**Remove "Channels" from Settings submenu:**

Delete the following lines from the Settings collapse section:

```erb
<%= link_to settings_channel_subscriptions_path, class: "menu-item ..." do %>
  <span class="grow">Channels</span>
<% end %>
```

**Sidebar order after change:**

1. Dashboard
2. Jobs
3. Videos (Videos, Import, Search)
4. **Channels (All Channels, Subscriptions)** -- NEW
5. Google Accounts
6. Comments
7. Settings (AI/Prompt, Project) -- "Channels" removed
8. SMM Panels (JAP)

---

## Phase 8: Rake Task

### 8.1 Create Rake Task

**File to create:** `lib/tasks/channels.rake`

```ruby
namespace :channels do
  desc "Populate channels from existing video raw_data and link videos to channels"
  task populate_from_videos: :environment do
    puts "Starting channel population from existing videos..."

    total_videos = Video.where("raw_data->>'channel_id' IS NOT NULL").count
    puts "Found #{total_videos} videos with channel_id in raw_data"

    created = 0
    linked = 0
    errors = 0

    Video.where("raw_data->>'channel_id' IS NOT NULL")
         .where(channel_id: nil)
         .find_each do |video|
      channel_id = video.raw_data["channel_id"]
      channel_title = video.raw_data["channel_title"]

      next if channel_id.blank?

      begin
        channel = Channel.find_or_create_by!(
          project: video.project,
          youtube_channel_id: channel_id
        ) do |ch|
          ch.name = channel_title
          created += 1
        end

        video.update_column(:channel_id, channel.id)
        linked += 1
      rescue => e
        errors += 1
        puts "  Error for video #{video.id} (#{video.youtube_id}): #{e.message}"
      end

      print "." if linked % 100 == 0
    end

    puts "\nDone!"
    puts "  Channels created: #{created}"
    puts "  Videos linked: #{linked}"
    puts "  Errors: #{errors}"

    # Optionally fetch metadata for channels that don't have thumbnails yet
    channels_without_metadata = Channel.where(thumbnail_url: nil).count
    if channels_without_metadata > 0
      puts "\n#{channels_without_metadata} channels have no metadata."
      puts "Run 'rails channels:fetch_metadata' to fetch from YouTube API."
    end
  end

  desc "Fetch YouTube metadata for channels missing thumbnail/subscriber data"
  task fetch_metadata: :environment do
    channels = Channel.where(thumbnail_url: nil)
    puts "Fetching metadata for #{channels.count} channels..."

    channels.find_each do |channel|
      channel.fetch_metadata!
      print "."
    end

    puts "\nDone!"
  end
end
```

**Two tasks provided:**

1. `rails channels:populate_from_videos` -- creates Channel records from `raw_data` and sets `video.channel_id`. Uses
   `find_each` for memory efficiency.
2. `rails channels:fetch_metadata` -- optional follow-up to enrich channels with thumbnails/subscriber counts from
   YouTube API.

---

## Phase 9: Cleanup & Polish

### 9.1 Update ChannelSubscription Model

**File to modify:** `app/models/channel_subscription.rb`

Update the `imported_videos_count` and `recent_videos` methods to use the Channel model when possible, but keep the
`channel_id` string field as-is (per requirements -- no over-engineering of the relationship):

```ruby
# These methods can now use Channel if one exists, but fall back to raw_data query
def imported_videos_count
  if (channel = project.channels.find_by(youtube_channel_id: channel_id))
    channel.videos.count
  else
    project.videos.where("raw_data->>'channel_id' = ?", channel_id).count
  end
end
```

This is optional and can be deferred. The existing raw_data queries still work fine.

### 9.2 Update YouTubeChannelSubscribeJob

**File to modify:** `app/jobs/youtube_channel_subscribe_job.rb`

After activating the subscription and fetching metadata, also ensure a Channel record exists:

```ruby
def activate_subscription
  @subscription.update!(status: :active, subscribed_at: Time.current)
  @subscription.fetch_channel_metadata!

  # Ensure a Channel record exists for this subscription
  Channel.find_or_create_from_video!(
    project: @subscription.project,
    channel_id: @subscription.channel_id,
    channel_title: @subscription.channel_name
  )
rescue StandardError => e
  # ...existing error handling...
end
```

---

## Implementation Order (Dependency Chain)

```
Step 1: Create channels migration + add channel_id to videos migration
        (Foundation -- everything depends on these tables)
             |
Step 2: Create Channel model + update Video/Project model associations
        (Model layer must exist before controllers/jobs can use it)
             |
Step 3: Create rake task and run it to populate existing data
        (Data must exist before the index page is useful)
             |
Step 4: Update FetchVideoMetadataJob + YouTubeChannelSubscribeJob
        (Future imports will create channels automatically)
             |
Step 5: Create ChannelsController + channels/index view
        (New index page -- can be tested standalone)
             |
Step 6: Create Channels::SubscriptionsController + views (index + new)
        (New namespace for subscriptions)
             |
Step 7: Update routes (add new, remove old settings routes)
             |
Step 8: Update sidebar (add Channels menu, remove from Settings)
             |
Step 9: Delete old Settings::ChannelSubscriptionsController + views
             |
Step 10: Cleanup -- update ChannelSubscription model methods (optional)
```

**Steps 5-8 can be done together** as they form a cohesive UI change. Steps 7-9 should be done atomically to avoid
broken links.

---

## Files Summary

### Files to CREATE (8 files)

| File                                                   | Purpose                                |
|--------------------------------------------------------|----------------------------------------|
| `db/migrate/XXXXXX_create_channels.rb`                 | Channels table migration               |
| `db/migrate/XXXXXX_add_channel_id_to_videos.rb`        | FK on videos                           |
| `app/models/channel.rb`                                | Channel model with stats scope         |
| `app/controllers/channels_controller.rb`               | Channels index page                    |
| `app/views/channels/index.html.erb`                    | Channels index view                    |
| `app/controllers/channels/subscriptions_controller.rb` | Subscriptions (moved from settings)    |
| `app/views/channels/subscriptions/index.html.erb`      | Subscriptions list (no form)           |
| `app/views/channels/subscriptions/new.html.erb`        | Subscribe form with rich channel cards |
| `lib/tasks/channels.rake`                              | Rake task to populate channels         |

### Files to MODIFY (7 files)

| File                                        | Change                                                     |
|---------------------------------------------|------------------------------------------------------------|
| `app/models/video.rb`                       | Add `belongs_to :channel, optional: true`                  |
| `app/models/project.rb`                     | Add `has_many :channels, dependent: :destroy`              |
| `app/jobs/fetch_video_metadata_job.rb`      | Add channel find_or_create after metadata update           |
| `app/jobs/youtube_channel_subscribe_job.rb` | Ensure Channel record on subscription activation           |
| `config/routes.rb`                          | Add channels routes, remove settings/channel_subscriptions |
| `app/views/shared/_sidebar.html.erb`        | Add Channels menu, remove from Settings                    |
| `app/models/channel_subscription.rb`        | (Optional) Use Channel model in helper methods             |

### Files to DELETE (2 files)

| File                                                           | Reason                                             |
|----------------------------------------------------------------|----------------------------------------------------|
| `app/controllers/settings/channel_subscriptions_controller.rb` | Replaced by `channels/subscriptions_controller.rb` |
| `app/views/settings/channel_subscriptions/index.html.erb`      | Replaced by new views                              |

---

## Risk Assessment & Edge Cases

1. **Race condition on Channel.find_or_create_by!**: Handled via `rescue ActiveRecord::RecordNotUnique` in the model
   method, plus the database unique index guarantees correctness.

2. **Videos without raw_data channel_id**: The rake task skips these (WHERE clause). The `belongs_to :channel` is
   `optional: true`.

3. **ChannelSubscription still has its own channel_id string**: This is intentional. The requirement says to keep it
   simple. A subscription references a YouTube channel by string ID. The Channel model is a separate entity. They share
   the same `youtube_channel_id` / `channel_id` value but are not FK-linked.

4. **Broken links during transition**: The route change from `settings/channel_subscriptions` to
   `channels/subscriptions` will break any bookmarks. This is acceptable for an internal tool. If needed, a redirect
   route can be added: `get 'settings/channel_subscriptions', to: redirect('/channels/subscriptions')`.

5. **Performance of `with_stats` scope**: The LEFT JOIN across channels -> videos -> comments could be slow with very
   large datasets. For now this matches the existing pattern in `VideosController#index`. If needed later, counter
   caches can be added.
