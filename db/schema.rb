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

ActiveRecord::Schema[8.1].define(version: 2026_03_18_025158) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "book_requests", force: :cascade do |t|
    t.decimal "additional_payment", precision: 12, scale: 2
    t.string "author"
    t.text "comment"
    t.string "cover_url"
    t.datetime "created_at", null: false
    t.integer "fiscal_period_id"
    t.string "link_url"
    t.integer "member_id"
    t.decimal "price", precision: 12, scale: 2
    t.string "publisher"
    t.string "rating"
    t.string "request_status"
    t.date "requested_on"
    t.string "source_key"
    t.string "source_system"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["fiscal_period_id"], name: "index_book_requests_on_fiscal_period_id"
    t.index ["member_id"], name: "index_book_requests_on_member_id"
    t.index ["request_status"], name: "index_book_requests_on_request_status"
    t.index ["requested_on"], name: "index_book_requests_on_requested_on"
    t.index ["source_system", "source_key"], name: "index_book_requests_on_source_system_and_source_key", unique: true, where: "source_key IS NOT NULL"
  end

  create_table "fiscal_periods", force: :cascade do |t|
    t.boolean "active", default: false, null: false
    t.datetime "created_at", null: false
    t.date "end_date", null: false
    t.string "name", null: false
    t.date "start_date", null: false
    t.datetime "updated_at", null: false
  end

  create_table "meeting_attendances", force: :cascade do |t|
    t.datetime "awarded_at"
    t.integer "awarded_points"
    t.string "awarded_policy_role"
    t.datetime "created_at", null: false
    t.integer "meeting_id", null: false
    t.integer "member_id", null: false
    t.text "note"
    t.integer "override_points"
    t.boolean "reserve_exempt", default: false, null: false
    t.string "source_key"
    t.string "source_system"
    t.datetime "updated_at", null: false
    t.index ["meeting_id", "member_id"], name: "index_meeting_attendances_on_meeting_id_and_member_id", unique: true
    t.index ["meeting_id"], name: "index_meeting_attendances_on_meeting_id"
    t.index ["member_id"], name: "index_meeting_attendances_on_member_id"
    t.index ["source_system", "source_key"], name: "index_meeting_attendances_on_source_system_and_source_key", unique: true, where: "source_key IS NOT NULL"
  end

  create_table "meeting_photos", force: :cascade do |t|
    t.string "caption"
    t.datetime "created_at", null: false
    t.string "file_path"
    t.integer "meeting_id", null: false
    t.integer "sort_order", default: 0, null: false
    t.string "source_key"
    t.string "source_system"
    t.string "source_url"
    t.datetime "updated_at", null: false
    t.index ["meeting_id"], name: "index_meeting_photos_on_meeting_id"
    t.index ["source_system", "source_key"], name: "index_meeting_photos_on_source_system_and_source_key", unique: true, where: "source_key IS NOT NULL"
  end

  create_table "meetings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "created_by_id"
    t.text "description"
    t.integer "fiscal_period_id"
    t.string "legacy_title"
    t.string "location"
    t.datetime "meeting_at", null: false
    t.boolean "reserve_exempt_default", default: false, null: false
    t.text "review"
    t.string "source_key"
    t.string "source_system"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_meetings_on_created_by_id"
    t.index ["fiscal_period_id"], name: "index_meetings_on_fiscal_period_id"
    t.index ["location"], name: "index_meetings_on_location"
    t.index ["meeting_at"], name: "index_meetings_on_meeting_at"
    t.index ["source_system", "source_key"], name: "index_meetings_on_source_system_and_source_key", unique: true, where: "source_key IS NOT NULL"
  end

  create_table "member_office_assignments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "created_by_id"
    t.date "effective_from", null: false
    t.date "effective_to"
    t.string "location"
    t.integer "member_id", null: false
    t.text "note"
    t.string "office_type", null: false
    t.string "source_key"
    t.string "source_system"
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_member_office_assignments_on_created_by_id"
    t.index ["member_id", "office_type", "location", "effective_from"], name: "index_member_office_assignments_on_member_scope_and_start", unique: true
    t.index ["member_id"], name: "index_member_office_assignments_on_member_id"
    t.index ["office_type", "location", "effective_from"], name: "index_member_office_assignments_on_office_scope_and_start"
    t.index ["source_system", "source_key"], name: "index_member_office_assignments_on_source_system_and_source_key", unique: true, where: "source_key IS NOT NULL"
  end

  create_table "members", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.text "bio"
    t.datetime "created_at", null: false
    t.string "department"
    t.string "email"
    t.string "english_name", null: false
    t.date "joined_on"
    t.string "korean_name"
    t.string "location"
    t.string "member_role", null: false
    t.string "source_key"
    t.string "source_system"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_members_on_email", unique: true
    t.index ["location"], name: "index_members_on_location"
    t.index ["member_role"], name: "index_members_on_member_role"
    t.index ["source_system", "source_key"], name: "index_members_on_source_system_and_source_key", unique: true, where: "source_key IS NOT NULL"
  end

  create_table "reserve_policies", force: :cascade do |t|
    t.integer "attendance_points", null: false
    t.datetime "created_at", null: false
    t.date "effective_from", null: false
    t.date "effective_to"
    t.string "member_role", null: false
    t.datetime "updated_at", null: false
    t.index ["member_role", "effective_from"], name: "index_reserve_policies_on_member_role_and_effective_from", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.integer "member_id"
    t.string "password_digest"
    t.string "role", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["member_id"], name: "index_users_on_member_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "book_requests", "fiscal_periods", on_delete: :nullify
  add_foreign_key "book_requests", "members", on_delete: :nullify
  add_foreign_key "meeting_attendances", "meetings", on_delete: :cascade
  add_foreign_key "meeting_attendances", "members", on_delete: :cascade
  add_foreign_key "meeting_photos", "meetings", on_delete: :cascade
  add_foreign_key "meetings", "fiscal_periods", on_delete: :nullify
  add_foreign_key "meetings", "users", column: "created_by_id", on_delete: :nullify
  add_foreign_key "member_office_assignments", "members", on_delete: :cascade
  add_foreign_key "member_office_assignments", "users", column: "created_by_id", on_delete: :nullify
  add_foreign_key "users", "members", on_delete: :nullify
end
