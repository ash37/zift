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

ActiveRecord::Schema[8.0].define(version: 2025_09_12_000001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "agreement_acceptances", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "agreement_id", null: false
    t.string "signed_name", null: false
    t.datetime "signed_at", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.string "content_hash", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agreement_id"], name: "index_agreement_acceptances_on_agreement_id"
    t.index ["user_id", "agreement_id"], name: "index_agreement_acceptances_on_user_id_and_agreement_id", unique: true
    t.index ["user_id"], name: "index_agreement_acceptances_on_user_id"
  end

  create_table "agreements", force: :cascade do |t|
    t.string "document_type", null: false
    t.integer "version", default: 1, null: false
    t.string "title", null: false
    t.text "body", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["document_type", "active"], name: "index_agreements_on_document_type_and_active"
    t.index ["document_type", "version"], name: "index_agreements_on_document_type_and_version", unique: true
  end

  create_table "areas", force: :cascade do |t|
    t.string "name"
    t.string "export_code"
    t.string "color"
    t.integer "location_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "archived_at"
    t.string "xero_item_code"
    t.boolean "show_timesheet_notes", default: true, null: false
    t.boolean "show_timesheet_travel", default: true, null: false
    t.index ["location_id"], name: "index_areas_on_location_id"
    t.index ["xero_item_code"], name: "index_areas_on_xero_item_code"
  end

  create_table "areas_shift_questions", force: :cascade do |t|
    t.bigint "area_id", null: false
    t.bigint "shift_question_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["area_id", "shift_question_id"], name: "idx_areas_shift_questions_uniqueness", unique: true
    t.index ["area_id"], name: "index_areas_shift_questions_on_area_id"
    t.index ["shift_question_id"], name: "index_areas_shift_questions_on_shift_question_id"
  end

  create_table "invoice_export_lines", force: :cascade do |t|
    t.integer "invoice_export_id", null: false
    t.integer "location_id", null: false
    t.integer "area_id", null: false
    t.string "xero_invoice_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "timesheet_id", null: false
    t.string "description"
    t.index ["area_id"], name: "index_invoice_export_lines_on_area_id"
    t.index ["invoice_export_id"], name: "index_invoice_export_lines_on_invoice_export_id"
    t.index ["location_id"], name: "index_invoice_export_lines_on_location_id"
    t.index ["timesheet_id"], name: "index_invoice_export_lines_on_timesheet_id"
  end

  create_table "invoice_exports", force: :cascade do |t|
    t.string "idempotency_key", null: false
    t.string "status", default: "pending", null: false
    t.integer "exported_count", default: 0
    t.integer "total_count", default: 0
    t.text "error_blob"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["idempotency_key"], name: "index_invoice_exports_on_idempotency_key", unique: true
  end

  create_table "items", force: :cascade do |t|
    t.bigint "location_id", null: false
    t.string "name", null: false
    t.date "expiry_date"
    t.text "info"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["location_id"], name: "index_items_on_location_id"
  end

  create_table "location_agreement_acceptances", force: :cascade do |t|
    t.bigint "location_id", null: false
    t.bigint "agreement_id", null: false
    t.string "email"
    t.string "signed_name"
    t.datetime "signed_at"
    t.string "ip_address"
    t.string "user_agent"
    t.string "content_hash", null: false
    t.string "token", null: false
    t.datetime "emailed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agreement_id"], name: "index_location_agreement_acceptances_on_agreement_id"
    t.index ["location_id", "agreement_id"], name: "idx_on_location_id_agreement_id_3ab4c917a4"
    t.index ["location_id"], name: "index_location_agreement_acceptances_on_location_id"
    t.index ["token"], name: "index_location_agreement_acceptances_on_token", unique: true
  end

  create_table "locations", force: :cascade do |t|
    t.string "name"
    t.string "address"
    t.float "latitude"
    t.float "longitude"
    t.integer "allowed_radius"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "archived_at"
    t.string "status"
    t.string "representative_name"
    t.string "representative_email"
    t.string "email"
    t.string "phone"
    t.date "date_of_birth"
    t.string "ndis_number"
    t.string "funding"
    t.string "plan_manager_email"
    t.text "interview_info"
    t.text "schedule_info"
    t.string "gender"
    t.text "lives_with"
    t.text "pets"
    t.text "activities_of_interest"
    t.text "tasks"
  end

  create_table "locations_users", id: false, force: :cascade do |t|
    t.bigint "location_id"
    t.bigint "user_id"
    t.index ["location_id"], name: "index_locations_users_on_location_id"
    t.index ["user_id"], name: "index_locations_users_on_user_id"
  end

  create_table "push_subscriptions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.text "endpoint", null: false
    t.text "p256dh", null: false
    t.text "auth", null: false
    t.boolean "active", default: true, null: false
    t.string "user_agent"
    t.string "platform"
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["endpoint"], name: "index_push_subscriptions_on_endpoint", unique: true
    t.index ["user_id"], name: "index_push_subscriptions_on_user_id"
  end

  create_table "recurrences", force: :cascade do |t|
    t.string "frequency"
    t.integer "interval"
    t.date "ends_on"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "reminder_sends", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "shift_id", null: false
    t.string "kind", null: false
    t.datetime "sent_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shift_id"], name: "index_reminder_sends_on_shift_id"
    t.index ["user_id", "shift_id", "kind"], name: "index_reminder_sends_unique", unique: true
    t.index ["user_id"], name: "index_reminder_sends_on_user_id"
  end

  create_table "rosters", force: :cascade do |t|
    t.date "starts_on"
    t.integer "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "emails_sent_at"
    t.text "public_holidays"
    t.index ["starts_on"], name: "index_rosters_on_starts_on_unique", unique: true
  end

  create_table "shift_answers", force: :cascade do |t|
    t.text "answer_text", null: false
    t.bigint "shift_id", null: false
    t.bigint "timesheet_id", null: false
    t.bigint "shift_question_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shift_id", "shift_question_id"], name: "idx_answers_shift_question"
    t.index ["shift_id"], name: "index_shift_answers_on_shift_id"
    t.index ["shift_question_id"], name: "index_shift_answers_on_shift_question_id"
    t.index ["timesheet_id", "shift_question_id"], name: "idx_answers_timesheet_question"
    t.index ["timesheet_id"], name: "index_shift_answers_on_timesheet_id"
    t.index ["user_id"], name: "index_shift_answers_on_user_id"
  end

  create_table "shift_questions", force: :cascade do |t|
    t.string "question_text", null: false
    t.string "question_type", null: false
    t.integer "display_order", default: 0, null: false
    t.boolean "is_mandatory", default: false, null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["display_order"], name: "index_shift_questions_on_display_order"
    t.index ["is_active"], name: "index_shift_questions_on_is_active"
    t.index ["question_type"], name: "index_shift_questions_on_question_type"
  end

  create_table "shift_types", force: :cascade do |t|
    t.string "name", null: false
    t.string "xero_earnings_rate_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_shift_types_on_name", unique: true
  end

  create_table "shifts", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "location_id", null: false
    t.integer "roster_id", null: false
    t.datetime "start_time"
    t.datetime "end_time"
    t.integer "recurrence_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "area_id"
    t.text "note"
    t.index ["area_id"], name: "index_shifts_on_area_id"
    t.index ["location_id"], name: "index_shifts_on_location_id"
    t.index ["roster_id"], name: "index_shifts_on_roster_id"
    t.index ["user_id"], name: "index_shifts_on_user_id"
  end

  create_table "test_enums", force: :cascade do |t|
    t.integer "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "timesheet_export_lines", force: :cascade do |t|
    t.integer "timesheet_export_id", null: false
    t.integer "user_id", null: false
    t.string "earnings_rate_id", null: false
    t.json "daily_units", null: false
    t.string "xero_timesheet_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["timesheet_export_id"], name: "index_timesheet_export_lines_on_timesheet_export_id"
    t.index ["user_id"], name: "index_timesheet_export_lines_on_user_id"
  end

  create_table "timesheet_exports", force: :cascade do |t|
    t.string "idempotency_key", null: false
    t.date "pay_period_start", null: false
    t.date "pay_period_end", null: false
    t.string "status", default: "pending", null: false
    t.integer "exported_count", default: 0
    t.integer "total_count", default: 0
    t.text "error_blob"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["idempotency_key"], name: "index_timesheet_exports_on_idempotency_key", unique: true
  end

  create_table "timesheets", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "shift_id", null: false
    t.datetime "clock_in_at"
    t.datetime "clock_out_at"
    t.integer "duration"
    t.integer "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "notes"
    t.decimal "travel", precision: 10, scale: 2, default: "0.0"
    t.boolean "auto_clock_off", default: false
    t.index ["shift_id"], name: "index_timesheets_on_shift_id"
    t.index ["user_id"], name: "index_timesheets_on_user_id"
  end

  create_table "unavailability_requests", force: :cascade do |t|
    t.integer "user_id", null: false
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.string "reason"
    t.integer "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "frequency"
    t.integer "repeat_day"
    t.boolean "repeats_weekly", default: false, null: false
    t.index ["repeats_weekly"], name: "index_unavailability_requests_on_repeats_weekly"
    t.index ["user_id"], name: "index_unavailability_requests_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.integer "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "encrypted_password"
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "status"
    t.string "gender"
    t.string "obtained_screening"
    t.date "date_of_birth"
    t.string "address"
    t.string "suburb"
    t.string "state"
    t.string "postcode"
    t.string "emergency_name"
    t.string "emergency_phone"
    t.string "disability_experience"
    t.string "other_experience"
    t.string "other_employment"
    t.string "licence"
    t.string "availability"
    t.text "bio"
    t.string "known_client"
    t.string "resident"
    t.string "education"
    t.string "qualification"
    t.string "bank_account"
    t.string "bsb"
    t.string "tfn"
    t.string "training"
    t.string "departure"
    t.datetime "yellow_expiry", precision: nil
    t.datetime "blue_expiry", precision: nil
    t.string "tfn_threshold"
    t.string "debt"
    t.string "super_name"
    t.string "super_number"
    t.string "invitation_token"
    t.datetime "invitation_sent_at"
    t.string "phone"
    t.string "xero_employee_id"
    t.datetime "archived_at"
    t.index ["archived_at"], name: "index_users_on_archived_at"
  end

  create_table "xero_connections", force: :cascade do |t|
    t.string "tenant_id", null: false
    t.string "access_token", null: false
    t.string "refresh_token", null: false
    t.string "scopes", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id"], name: "index_xero_connections_on_tenant_id", unique: true
  end

  create_table "xero_items", force: :cascade do |t|
    t.string "code", null: false
    t.string "name"
    t.string "xero_item_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_xero_items_on_code", unique: true
    t.index ["xero_item_id"], name: "index_xero_items_on_xero_item_id", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "agreement_acceptances", "agreements"
  add_foreign_key "agreement_acceptances", "users"
  add_foreign_key "areas", "locations"
  add_foreign_key "areas_shift_questions", "areas"
  add_foreign_key "areas_shift_questions", "shift_questions"
  add_foreign_key "invoice_export_lines", "areas"
  add_foreign_key "invoice_export_lines", "invoice_exports"
  add_foreign_key "invoice_export_lines", "locations"
  add_foreign_key "invoice_export_lines", "timesheets"
  add_foreign_key "items", "locations"
  add_foreign_key "location_agreement_acceptances", "agreements"
  add_foreign_key "location_agreement_acceptances", "locations"
  add_foreign_key "push_subscriptions", "users"
  add_foreign_key "reminder_sends", "shifts"
  add_foreign_key "reminder_sends", "users"
  add_foreign_key "shift_answers", "shift_questions"
  add_foreign_key "shift_answers", "shifts"
  add_foreign_key "shift_answers", "timesheets"
  add_foreign_key "shift_answers", "users"
  add_foreign_key "shifts", "areas"
  add_foreign_key "shifts", "locations"
  add_foreign_key "shifts", "rosters"
  add_foreign_key "shifts", "users"
  add_foreign_key "timesheet_export_lines", "timesheet_exports"
  add_foreign_key "timesheet_export_lines", "users"
  add_foreign_key "timesheets", "shifts"
  add_foreign_key "timesheets", "users"
  add_foreign_key "unavailability_requests", "users"
end
