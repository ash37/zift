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

ActiveRecord::Schema[8.0].define(version: 2025_08_11_030910) do
  create_table "areas", force: :cascade do |t|
    t.string "name"
    t.string "export_code"
    t.string "color"
    t.integer "location_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "archived_at"
    t.index ["location_id"], name: "index_areas_on_location_id"
  end

  create_table "locations", force: :cascade do |t|
    t.string "name"
    t.string "address"
    t.float "latitude"
    t.float "longitude"
    t.integer "allowed_radius"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.integer "travel"
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
    t.integer "location_id"
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
    t.index ["location_id"], name: "index_users_on_location_id"
  end

  add_foreign_key "areas", "locations"
  add_foreign_key "shifts", "areas"
  add_foreign_key "shifts", "locations"
  add_foreign_key "shifts", "rosters"
  add_foreign_key "shifts", "users"
  add_foreign_key "timesheets", "shifts"
  add_foreign_key "timesheets", "users"
  add_foreign_key "unavailability_requests", "users"
  add_foreign_key "users", "locations"
end
