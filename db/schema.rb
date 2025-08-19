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

ActiveRecord::Schema[8.0].define(version: 2025_08_19_093919) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "areas", force: :cascade do |t|
    t.string "name"
    t.string "export_code"
    t.string "color"
    t.integer "location_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "archived_at"
    t.string "xero_item_code"
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

  create_table "locations", force: :cascade do |t|
    t.string "name"
    t.string "address"
    t.float "latitude"
    t.float "longitude"
    t.integer "allowed_radius"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "archived_at"
  end

  create_table "locations_users", id: false, force: :cascade do |t|
    t.bigint "location_id"
    t.bigint "user_id"
    t.index ["location_id"], name: "index_locations_users_on_location_id"
    t.index ["user_id"], name: "index_locations_users_on_user_id"
  end

  create_table "recurrences", force: :cascade do |t|
    t.string "frequency"
    t.integer "interval"
    t.date "ends_on"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "rosters", force: :cascade do |t|
    t.date "starts_on"
    t.integer "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "emails_sent_at"
    t.text "public_holidays"
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
    t.string "yellow_expiry"
    t.string "blue_expiry"
    t.string "tfn_threshold"
    t.string "debt"
    t.string "super_name"
    t.string "super_number"
    t.string "invitation_token"
    t.datetime "invitation_sent_at"
    t.string "phone"
    t.string "xero_employee_id"
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

  add_foreign_key "areas", "locations"
  add_foreign_key "areas_shift_questions", "areas"
  add_foreign_key "areas_shift_questions", "shift_questions"
  add_foreign_key "invoice_export_lines", "areas"
  add_foreign_key "invoice_export_lines", "invoice_exports"
  add_foreign_key "invoice_export_lines", "locations"
  add_foreign_key "invoice_export_lines", "timesheets"
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
