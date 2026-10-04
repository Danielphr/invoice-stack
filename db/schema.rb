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

ActiveRecord::Schema[8.1].define(version: 2026_10_04_011638) do
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

  create_table "clients", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.string "name", null: false
    t.string "email"
    t.string "phone"
    t.string "website"
    t.text "notes"
    t.string "address_line1"
    t.string "address_line2"
    t.string "city", null: false
    t.string "state"
    t.string "postal_code"
    t.string "country", null: false
    t.string "contact_first_name"
    t.string "contact_last_name"
    t.string "contact_email"
    t.string "contact_phone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id", "id"], name: "index_clients_on_company_id_and_id", unique: true
    t.index ["company_id", "name"], name: "index_clients_on_company_id_and_name"
  end

  create_table "companies", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "invoice_number_pattern", default: "INV-{NUMBER}", null: false
    t.integer "invoice_number_digits", default: 1, null: false
    t.integer "next_invoice_number", default: 1, null: false
    t.string "email"
    t.string "address_line1"
    t.string "address_line2"
    t.string "city"
    t.string "state"
    t.string "postal_code"
    t.string "country"
    t.string "time_zone", default: "UTC", null: false
    t.string "default_currency", default: "USD", null: false
    t.string "accent_color", default: "#000000", null: false
    t.text "default_invoice_notes"
    t.check_constraint "POSITION(('{NUMBER}'::text) IN (invoice_number_pattern)) > 0", name: "companies_invoice_number_pattern_check"
    t.check_constraint "accent_color::text ~ '^#[0-9a-f]{6}$'::text", name: "companies_accent_color_check"
    t.check_constraint "invoice_number_digits >= 1 AND invoice_number_digits <= 10", name: "companies_invoice_number_digits_check"
    t.check_constraint "next_invoice_number >= 1", name: "companies_next_invoice_number_check"
  end

  create_table "invoice_items", force: :cascade do |t|
    t.bigint "invoice_id", null: false
    t.string "description", null: false
    t.decimal "quantity", precision: 10, scale: 2, null: false
    t.decimal "unit_price", precision: 12, scale: 2, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invoice_id"], name: "index_invoice_items_on_invoice_id"
    t.check_constraint "quantity > 0::numeric", name: "invoice_items_quantity_check"
    t.check_constraint "unit_price >= 0::numeric", name: "invoice_items_unit_price_check"
  end

  create_table "invoices", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.bigint "client_id", null: false
    t.string "number"
    t.string "status", default: "draft", null: false
    t.string "billing_type", default: "fixed", null: false
    t.string "currency", null: false
    t.date "issue_date", null: false
    t.date "due_date"
    t.decimal "discount", precision: 12, scale: 2, default: "0.0", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "paid_on"
    t.integer "sequence"
    t.index ["company_id", "client_id"], name: "index_invoices_on_company_id_and_client_id"
    t.index ["company_id", "number"], name: "index_invoices_on_company_id_and_number", unique: true
    t.index ["company_id", "sequence"], name: "index_invoices_on_company_id_and_sequence", unique: true
    t.check_constraint "(number IS NULL) = (sequence IS NULL)", name: "invoices_number_sequence_check"
    t.check_constraint "(status::text = 'draft'::text) = (number IS NULL)", name: "invoices_number_check"
    t.check_constraint "(status::text = 'paid'::text) = (paid_on IS NOT NULL)", name: "invoices_paid_on_check"
    t.check_constraint "billing_type::text = ANY (ARRAY['fixed'::character varying, 'hourly'::character varying]::text[])", name: "invoices_billing_type_check"
    t.check_constraint "discount >= 0::numeric", name: "invoices_discount_check"
    t.check_constraint "due_date IS NULL OR due_date >= issue_date", name: "invoices_due_date_check"
    t.check_constraint "sequence > 0", name: "invoices_sequence_check"
    t.check_constraint "status::text = ANY (ARRAY['draft'::character varying, 'sent'::character varying, 'paid'::character varying, 'cancelled'::character varying]::text[])", name: "invoices_status_check"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.bigint "company_id", null: false
    t.index ["company_id"], name: "index_users_on_company_id"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "clients", "companies"
  add_foreign_key "invoice_items", "invoices", on_delete: :cascade
  add_foreign_key "invoices", "clients", column: ["company_id", "client_id"], primary_key: ["company_id", "id"]
  add_foreign_key "invoices", "companies"
  add_foreign_key "sessions", "users"
  add_foreign_key "users", "companies"
end
