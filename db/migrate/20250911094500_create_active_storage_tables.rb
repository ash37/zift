class CreateActiveStorageTables < ActiveRecord::Migration[8.0]
  def change
    # Active Storage blobs
    create_table :active_storage_blobs, if_not_exists: true do |t|
      t.string   :key,          null: false
      t.string   :filename,     null: false
      t.string   :content_type
      t.text     :metadata
      t.string   :service_name, null: false
      t.bigint   :byte_size,    null: false
      t.string   :checksum
      t.datetime :created_at,   null: false
    end
    add_index :active_storage_blobs, :key, unique: true, if_not_exists: true

    # Active Storage attachments
    create_table :active_storage_attachments, if_not_exists: true do |t|
      t.string     :name,        null: false
      t.string     :record_type, null: false
      t.bigint     :record_id,   null: false
      t.bigint     :blob_id,     null: false
      t.datetime   :created_at,  null: false
    end
    add_index :active_storage_attachments, [:blob_id], name: "index_active_storage_attachments_on_blob_id", if_not_exists: true
    add_index :active_storage_attachments, [:record_type, :record_id, :name, :blob_id], name: "index_active_storage_attachments_uniqueness", unique: true, if_not_exists: true

    # Variants (for image transformations)
    create_table :active_storage_variant_records, if_not_exists: true do |t|
      t.bigint :blob_id,          null: false
      t.string :variation_digest, null: false
    end
    add_index :active_storage_variant_records, [:blob_id, :variation_digest], name: "index_active_storage_variant_records_uniqueness", unique: true, if_not_exists: true

    add_foreign_key :active_storage_attachments, :active_storage_blobs, column: :blob_id unless foreign_key_exists?(:active_storage_attachments, :active_storage_blobs, column: :blob_id)
    add_foreign_key :active_storage_variant_records, :active_storage_blobs, column: :blob_id unless foreign_key_exists?(:active_storage_variant_records, :active_storage_blobs, column: :blob_id)
  end
end
