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

ActiveRecord::Schema[8.1].define(version: 2026_05_14_125808) do
  create_table "actors", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.integer "free_balance_cents", default: 0, null: false
    t.integer "paid_balance_cents", default: 0, null: false
    t.string "password_digest", null: false
    t.datetime "password_reset_sent_at"
    t.string "password_reset_token"
    t.string "payment_customer_id"
    t.string "payment_provider"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_actors_on_email", unique: true
  end

  create_table "capability_logs", force: :cascade do |t|
    t.string "actor_id", null: false
    t.string "capability", null: false
    t.string "charged_to", default: "actor", null: false
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.string "error_code"
    t.datetime "invoked_at", null: false
    t.integer "markup_cents", default: 0, null: false
    t.text "metadata_json"
    t.string "provider"
    t.string "provider_request_id"
    t.integer "raw_cost_cents", default: 0, null: false
    t.string "status", default: "success", null: false
    t.integer "total_charged_cents", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "version"
    t.index ["actor_id"], name: "index_capability_logs_on_actor_id"
    t.index ["capability"], name: "index_capability_logs_on_capability"
    t.index ["invoked_at"], name: "index_capability_logs_on_invoked_at"
    t.index ["provider"], name: "index_capability_logs_on_provider"
  end

  create_table "external_items", force: :cascade do |t|
    t.string "access_token_encrypted"
    t.string "access_token_encrypted_iv"
    t.string "actor_id", null: false
    t.datetime "created_at", null: false
    t.string "external_id"
    t.string "item_type"
    t.text "metadata_json"
    t.string "provider", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_external_items_on_actor_id"
    t.index ["external_id"], name: "index_external_items_on_external_id", unique: true
    t.index ["provider"], name: "index_external_items_on_provider"
  end

  create_table "submission_records", force: :cascade do |t|
    t.string "actor_id", null: false
    t.string "capability", null: false
    t.datetime "created_at", null: false
    t.string "idempotency_key"
    t.text "payload"
    t.string "public_key"
    t.string "signature"
    t.string "status", default: "submitted", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_submission_records_on_actor_id"
    t.index ["capability"], name: "index_submission_records_on_capability"
    t.index ["idempotency_key"], name: "index_submission_records_on_idempotency_key", unique: true
  end
end
