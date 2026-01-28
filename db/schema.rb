# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_01_27_193100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "comments", force: :cascade do |t|
    t.string "youtube_comment_id"
    t.text "text", null: false
    t.bigint "video_id", null: false
    t.bigint "parent_id"
    t.integer "status", default: 0, null: false
    t.integer "like_count", default: 0
    t.integer "rank"
    t.bigint "google_account_id"
    t.bigint "project_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "post_type", default: 0
    t.string "author_display_name", default: "", null: false
    t.string "author_avatar_url", default: "", null: false
    t.index ["google_account_id"], name: "index_comments_on_google_account_id"
    t.index ["parent_id"], name: "index_comments_on_parent_id"
    t.index ["project_id"], name: "index_comments_on_project_id"
    t.index ["status"], name: "index_comments_on_status"
    t.index ["video_id", "parent_id"], name: "index_comments_on_video_id_and_parent_id"
    t.index ["video_id"], name: "index_comments_on_video_id"
    t.index ["youtube_comment_id"], name: "index_comments_on_youtube_comment_id"
  end

  create_table "good_job_batches", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "description"
    t.jsonb "serialized_properties"
    t.text "on_finish"
    t.text "on_success"
    t.text "on_discard"
    t.text "callback_queue_name"
    t.integer "callback_priority"
    t.datetime "enqueued_at"
    t.datetime "discarded_at"
    t.datetime "finished_at"
    t.datetime "jobs_finished_at"
  end

  create_table "good_job_executions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "active_job_id", null: false
    t.text "job_class"
    t.text "queue_name"
    t.jsonb "serialized_params"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.text "error"
    t.integer "error_event", limit: 2
    t.text "error_backtrace", array: true
    t.uuid "process_id"
    t.interval "duration"
    t.index ["active_job_id", "created_at"], name: "index_good_job_executions_on_active_job_id_and_created_at"
    t.index ["process_id", "created_at"], name: "index_good_job_executions_on_process_id_and_created_at"
  end

  create_table "good_job_processes", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "state"
    t.integer "lock_type", limit: 2
  end

  create_table "good_job_settings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "key"
    t.jsonb "value"
    t.index ["key"], name: "index_good_job_settings_on_key", unique: true
  end

  create_table "good_jobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.text "queue_name"
    t.integer "priority"
    t.jsonb "serialized_params"
    t.datetime "scheduled_at"
    t.datetime "performed_at"
    t.datetime "finished_at"
    t.text "error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "active_job_id"
    t.text "concurrency_key"
    t.text "cron_key"
    t.uuid "retried_good_job_id"
    t.datetime "cron_at"
    t.uuid "batch_id"
    t.uuid "batch_callback_id"
    t.boolean "is_discrete"
    t.integer "executions_count"
    t.text "job_class"
    t.integer "error_event", limit: 2
    t.text "labels", array: true
    t.uuid "locked_by_id"
    t.datetime "locked_at"
    t.index ["active_job_id", "created_at"], name: "index_good_jobs_on_active_job_id_and_created_at"
    t.index ["batch_callback_id"], name: "index_good_jobs_on_batch_callback_id", where: "(batch_callback_id IS NOT NULL)"
    t.index ["batch_id"], name: "index_good_jobs_on_batch_id", where: "(batch_id IS NOT NULL)"
    t.index ["concurrency_key", "created_at"], name: "index_good_jobs_on_concurrency_key_and_created_at"
    t.index ["concurrency_key"], name: "index_good_jobs_on_concurrency_key_when_unfinished", where: "(finished_at IS NULL)"
    t.index ["cron_key", "created_at"], name: "index_good_jobs_on_cron_key_and_created_at_cond", where: "(cron_key IS NOT NULL)"
    t.index ["cron_key", "cron_at"], name: "index_good_jobs_on_cron_key_and_cron_at_cond", unique: true, where: "(cron_key IS NOT NULL)"
    t.index ["finished_at"], name: "index_good_jobs_jobs_on_finished_at_only", where: "(finished_at IS NOT NULL)"
    t.index ["job_class"], name: "index_good_jobs_on_job_class"
    t.index ["labels"], name: "index_good_jobs_on_labels", where: "(labels IS NOT NULL)", using: :gin
    t.index ["locked_by_id"], name: "index_good_jobs_on_locked_by_id", where: "(locked_by_id IS NOT NULL)"
    t.index ["priority", "created_at"], name: "index_good_job_jobs_for_candidate_lookup", where: "(finished_at IS NULL)"
    t.index ["priority", "created_at"], name: "index_good_jobs_jobs_on_priority_created_at_when_unfinished", order: { priority: "DESC NULLS LAST" }, where: "(finished_at IS NULL)"
    t.index ["priority", "scheduled_at"], name: "index_good_jobs_on_priority_scheduled_at_unfinished_unlocked", where: "((finished_at IS NULL) AND (locked_by_id IS NULL))"
    t.index ["queue_name", "scheduled_at"], name: "index_good_jobs_on_queue_name_and_scheduled_at", where: "(finished_at IS NULL)"
    t.index ["scheduled_at"], name: "index_good_jobs_on_scheduled_at", where: "(finished_at IS NULL)"
  end

  create_table "google_accounts", force: :cascade do |t|
    t.string "google_id", null: false
    t.string "email"
    t.string "name"
    t.string "youtube_channel_id"
    t.string "youtube_handle"
    t.string "avatar_url"
    t.string "access_token"
    t.string "refresh_token"
    t.datetime "token_expires_at"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "token_status", default: 0, null: false
    t.index ["google_id", "user_id"], name: "index_google_accounts_on_google_id_and_user_id", unique: true
    t.index ["google_id"], name: "index_google_accounts_on_google_id"
    t.index ["token_status"], name: "index_google_accounts_on_token_status"
    t.index ["user_id"], name: "index_google_accounts_on_user_id"
  end

  create_table "job_schedules", force: :cascade do |t|
    t.string "job_class", null: false
    t.integer "interval_minutes", default: 10, null: false
    t.boolean "enabled", default: false, null: false
    t.datetime "last_run_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["enabled"], name: "index_job_schedules_on_enabled"
    t.index ["job_class"], name: "index_job_schedules_on_job_class", unique: true
  end

  create_table "project_members", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "project_id", null: false
    t.integer "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_project_members_on_project_id"
    t.index ["user_id", "project_id"], name: "index_project_members_on_user_id_and_project_id", unique: true
    t.index ["user_id"], name: "index_project_members_on_user_id"
  end

  create_table "projects", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "prompt_settings", default: {}, null: false
  end

  create_table "smm_orders", force: :cascade do |t|
    t.bigint "smm_panel_credential_id", null: false
    t.bigint "project_id", null: false
    t.bigint "video_id"
    t.bigint "comment_id"
    t.string "external_order_id"
    t.integer "service_type", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.integer "quantity"
    t.decimal "charge", precision: 10, scale: 5
    t.integer "start_count"
    t.integer "remains"
    t.string "currency"
    t.string "link"
    t.jsonb "raw_response", default: {}
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["comment_id"], name: "index_smm_orders_on_comment_id"
    t.index ["external_order_id"], name: "index_smm_orders_on_external_order_id"
    t.index ["project_id"], name: "index_smm_orders_on_project_id"
    t.index ["service_type"], name: "index_smm_orders_on_service_type"
    t.index ["smm_panel_credential_id"], name: "index_smm_orders_on_smm_panel_credential_id"
    t.index ["status"], name: "index_smm_orders_on_status"
    t.index ["video_id"], name: "index_smm_orders_on_video_id"
  end

  create_table "smm_panel_credentials", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "panel_type", null: false
    t.string "api_key", null: false
    t.string "comment_service_id"
    t.string "upvote_service_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "panel_type"], name: "index_smm_panel_credentials_on_user_id_and_panel_type", unique: true
    t.index ["user_id"], name: "index_smm_panel_credentials_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "preferences", default: {}, null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "videos", force: :cascade do |t|
    t.string "youtube_id", null: false
    t.string "title"
    t.text "description"
    t.integer "comment_count", default: 0
    t.integer "like_count", default: 0
    t.integer "view_count", default: 0
    t.string "thumbnail_url"
    t.datetime "fetched_at"
    t.jsonb "raw_data", default: {}
    t.bigint "project_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id"], name: "index_videos_on_project_id"
    t.index ["youtube_id", "project_id"], name: "index_videos_on_youtube_id_and_project_id", unique: true
    t.index ["youtube_id"], name: "index_videos_on_youtube_id"
  end

  add_foreign_key "comments", "comments", column: "parent_id"
  add_foreign_key "comments", "google_accounts"
  add_foreign_key "comments", "projects"
  add_foreign_key "comments", "videos"
  add_foreign_key "google_accounts", "users"
  add_foreign_key "project_members", "projects"
  add_foreign_key "project_members", "users"
  add_foreign_key "smm_orders", "comments"
  add_foreign_key "smm_orders", "projects"
  add_foreign_key "smm_orders", "smm_panel_credentials"
  add_foreign_key "smm_orders", "videos"
  add_foreign_key "smm_panel_credentials", "users"
  add_foreign_key "videos", "projects"
end
