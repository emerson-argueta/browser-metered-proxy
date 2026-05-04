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

ActiveRecord::Schema[8.1].define(version: 2026_04_29_222733) do
  create_table "landlord_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.string "landlord_id"
    t.datetime "last_used_at"
    t.string "token_digest"
    t.datetime "updated_at", null: false
  end

  create_table "plaid_items", force: :cascade do |t|
    t.string "access_token_encrypted"
    t.string "access_token_encrypted_iv"
    t.string "account_id"
    t.string "account_name"
    t.string "account_type"
    t.datetime "created_at", null: false
    t.string "institution_name"
    t.string "item_id"
    t.string "item_type"
    t.string "landlord_id"
    t.datetime "updated_at", null: false
  end

  create_table "usage_records", force: :cascade do |t|
    t.string "call_type"
    t.datetime "called_at"
    t.string "charged_to"
    t.datetime "created_at", null: false
    t.string "landlord_id"
    t.integer "markup_cents"
    t.text "notes"
    t.string "plaid_request_id"
    t.string "property_id"
    t.integer "raw_cost_cents"
    t.string "status"
    t.string "tenant_id"
    t.integer "total_charged_cents"
    t.string "unit_id"
    t.datetime "updated_at", null: false
  end
end
