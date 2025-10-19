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

ActiveRecord::Schema[8.0].define(version: 2025_10_19_153000) do
  create_table "blog_posts", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "title", null: false
    t.string "slug", limit: 191, null: false
    t.integer "user_id", null: false
    t.text "body", null: false
    t.text "markeddown_body", null: false
    t.datetime "published_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "draft", default: false, null: false
    t.integer "legacy_identifier"
    t.index ["draft"], name: "index_blog_posts_on_draft"
    t.index ["legacy_identifier"], name: "index_blog_posts_on_legacy_identifier", unique: true
    t.index ["published_at"], name: "index_blog_posts_on_published_at"
    t.index ["slug"], name: "index_blog_posts_on_slug", unique: true
    t.index ["user_id"], name: "fk_rails_829fc99162"
  end

  create_table "comments", id: :integer, charset: "latin1", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil
    t.string "short_id", limit: 10, default: "", null: false
    t.integer "story_id", null: false
    t.integer "user_id", null: false
    t.integer "parent_comment_id"
    t.integer "thread_id"
    t.text "comment", size: :medium, null: false
    t.integer "upvotes", default: 0, null: false
    t.integer "downvotes", default: 0, null: false
    t.decimal "confidence", precision: 20, scale: 19, default: "0.0", null: false
    t.text "markeddown_comment", size: :medium
    t.boolean "is_deleted", default: false
    t.boolean "is_moderated", default: false
    t.boolean "is_from_email", default: false
    t.integer "hat_id"
    t.boolean "is_dragon", default: false
    t.index ["comment"], name: "fulltext_comments", type: :fulltext
    t.index ["confidence"], name: "confidence_idx"
    t.index ["short_id"], name: "short_id", unique: true
    t.index ["story_id", "short_id"], name: "story_id_short_id"
    t.index ["thread_id"], name: "thread_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "hat_requests", id: :integer, charset: "latin1", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
    t.string "hat"
    t.string "link"
    t.text "comment"
  end

  create_table "hats", id: :integer, charset: "latin1", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.integer "user_id"
    t.integer "granted_by_user_id"
    t.string "hat"
    t.string "link"
  end

  create_table "hidden_stories", id: :integer, charset: "latin1", force: :cascade do |t|
    t.integer "user_id"
    t.integer "story_id"
    t.index ["user_id", "story_id"], name: "index_hidden_stories_on_user_id_and_story_id", unique: true
  end

  create_table "invitation_requests", id: :integer, charset: "latin1", force: :cascade do |t|
    t.string "code"
    t.boolean "is_verified", default: false
    t.string "email"
    t.string "name"
    t.text "memo"
    t.string "ip_address"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
  end

  create_table "invitations", id: :integer, charset: "latin1", force: :cascade do |t|
    t.integer "user_id"
    t.string "email"
    t.string "code"
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.text "memo", size: :medium
  end

  create_table "keystores", id: false, charset: "latin1", force: :cascade do |t|
    t.string "key", limit: 50, default: "", null: false
    t.bigint "value"
    t.index ["key"], name: "key", unique: true
  end

  create_table "messages", id: :integer, charset: "latin1", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.integer "author_user_id"
    t.integer "recipient_user_id"
    t.boolean "has_been_read", default: false
    t.string "subject", limit: 100
    t.text "body", size: :medium
    t.string "short_id", limit: 30
    t.boolean "deleted_by_author", default: false
    t.boolean "deleted_by_recipient", default: false
    t.index ["short_id"], name: "random_hash", unique: true
  end

  create_table "moderations", id: :integer, charset: "latin1", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "moderator_user_id"
    t.integer "story_id"
    t.integer "comment_id"
    t.integer "user_id"
    t.text "action", size: :medium
    t.text "reason", size: :medium
    t.boolean "is_from_suggestions", default: false
  end

  create_table "stories", id: :integer, charset: "latin1", force: :cascade do |t|
    t.datetime "created_at", precision: nil
    t.integer "user_id"
    t.string "url", limit: 250, default: ""
    t.string "title", limit: 150, default: "", null: false
    t.text "description", size: :medium
    t.string "short_id", limit: 6, default: "", null: false
    t.boolean "is_expired", default: false, null: false
    t.integer "upvotes", default: 0, null: false
    t.integer "downvotes", default: 0, null: false
    t.boolean "is_moderated", default: false, null: false
    t.decimal "hotness", precision: 20, scale: 10, default: "0.0", null: false
    t.text "markeddown_description", size: :medium
    t.text "story_cache", size: :medium
    t.integer "comments_count", default: 0, null: false
    t.integer "merged_story_id"
    t.datetime "unavailable_at", precision: nil
    t.string "twitter_id", limit: 20
    t.boolean "user_is_author", default: false
    t.index ["created_at"], name: "index_stories_on_created_at"
    t.index ["hotness"], name: "hotness_idx"
    t.index ["is_expired", "is_moderated"], name: "is_idxes"
    t.index ["merged_story_id"], name: "index_stories_on_merged_story_id"
    t.index ["short_id"], name: "unique_short_id", unique: true
    t.index ["title", "description", "url"], name: "fulltext_stories", type: :fulltext
    t.index ["twitter_id"], name: "index_stories_on_twitter_id"
    t.index ["url"], name: "url", length: 191
  end

  create_table "suggested_taggings", id: :integer, charset: "latin1", force: :cascade do |t|
    t.integer "story_id"
    t.integer "tag_id"
    t.integer "user_id"
  end

  create_table "suggested_titles", id: :integer, charset: "latin1", force: :cascade do |t|
    t.integer "story_id"
    t.integer "user_id"
    t.string "title", limit: 150, null: false
  end

  create_table "tag_filters", id: :integer, charset: "latin1", force: :cascade do |t|
    t.datetime "created_at", precision: nil, null: false
    t.datetime "updated_at", precision: nil, null: false
    t.integer "user_id"
    t.integer "tag_id"
    t.index ["user_id", "tag_id"], name: "user_tag_idx"
  end

  create_table "taggings", id: :integer, charset: "latin1", force: :cascade do |t|
    t.integer "story_id", null: false
    t.integer "tag_id", null: false
    t.index ["story_id", "tag_id"], name: "story_id_tag_id", unique: true
  end

  create_table "tags", id: :integer, charset: "latin1", force: :cascade do |t|
    t.string "tag", limit: 25, default: "", null: false
    t.string "description", limit: 100
    t.boolean "privileged", default: false
    t.boolean "is_media", default: false
    t.boolean "inactive", default: false
    t.float "hotness_mod", default: 0.0
    t.index ["tag"], name: "tag", unique: true
  end

  create_table "users", id: :integer, charset: "latin1", force: :cascade do |t|
    t.string "username", limit: 50
    t.string "email", limit: 100
    t.string "password_digest", limit: 75
    t.datetime "created_at", precision: nil
    t.boolean "is_admin", default: false
    t.string "password_reset_token", limit: 75
    t.string "session_token", limit: 75, default: "", null: false
    t.text "about", size: :medium
    t.integer "invited_by_user_id"
    t.boolean "is_moderator", default: false
    t.boolean "pushover_mentions", default: false
    t.string "rss_token", limit: 75
    t.string "mailing_list_token", limit: 75
    t.integer "mailing_list_mode", default: 0
    t.integer "karma", default: 0, null: false
    t.datetime "banned_at", precision: nil
    t.integer "banned_by_user_id"
    t.string "banned_reason", limit: 200
    t.datetime "deleted_at", precision: nil
    t.datetime "disabled_invite_at", precision: nil
    t.integer "disabled_invite_by_user_id"
    t.string "disabled_invite_reason", limit: 200
    t.text "settings"
    t.index ["mailing_list_mode"], name: "mailing_list_enabled"
    t.index ["mailing_list_token"], name: "mailing_list_token", unique: true
    t.index ["password_reset_token"], name: "password_reset_token", unique: true
    t.index ["rss_token"], name: "rss_token", unique: true
    t.index ["session_token"], name: "session_hash", unique: true
    t.index ["username"], name: "username", unique: true
  end

  create_table "votes", id: :integer, charset: "latin1", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "story_id", null: false
    t.integer "comment_id"
    t.integer "vote", limit: 1, null: false
    t.string "reason", limit: 1
    t.index ["comment_id"], name: "index_votes_on_comment_id"
    t.index ["user_id", "comment_id"], name: "user_id_comment_id"
    t.index ["user_id", "story_id"], name: "user_id_story_id"
  end

  add_foreign_key "blog_posts", "users"
end
