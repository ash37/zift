class CreateAgreementsAndAcceptances < ActiveRecord::Migration[8.0]
  def change
    create_table :agreements do |t|
      t.string  :document_type, null: false # 'employment' | 'service'
      t.integer :version,       null: false, default: 1
      t.string  :title,         null: false
      t.text    :body,          null: false
      t.boolean :active,        null: false, default: true
      t.timestamps
    end
    add_index :agreements, [ :document_type, :version ], unique: true
    add_index :agreements, [ :document_type, :active ]

    create_table :agreement_acceptances do |t|
      t.references :user,      null: false, foreign_key: true
      t.references :agreement, null: false, foreign_key: true
      t.string :signed_name,  null: false
      t.datetime :signed_at,   null: false
      t.string  :ip_address
      t.string  :user_agent
      t.string  :content_hash, null: false
      t.timestamps
    end
    add_index :agreement_acceptances, [ :user_id, :agreement_id ], unique: true
  end
end
