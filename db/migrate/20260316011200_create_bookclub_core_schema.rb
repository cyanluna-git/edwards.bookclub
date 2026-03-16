class CreateBookclubCoreSchema < ActiveRecord::Migration[8.1]
  def change
    create_table :fiscal_periods do |t|
      t.string :name, null: false
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.boolean :active, null: false, default: false

      t.timestamps
    end

    create_table :members do |t|
      t.string :english_name, null: false
      t.string :korean_name
      t.string :department
      t.string :email
      t.string :member_role, null: false
      t.string :location
      t.boolean :active, null: false, default: true
      t.date :joined_on
      t.text :bio

      t.timestamps
    end

    add_index :members, :email, unique: true
    add_index :members, :location
    add_index :members, :member_role

    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest
      t.string :role, null: false
      t.references :member, foreign_key: { on_delete: :nullify }

      t.timestamps
    end

    add_index :users, :email, unique: true

    create_table :reserve_policies do |t|
      t.string :member_role, null: false
      t.integer :attendance_points, null: false
      t.date :effective_from, null: false
      t.date :effective_to

      t.timestamps
    end

    add_index :reserve_policies, [:member_role, :effective_from], unique: true

    create_table :meetings do |t|
      t.string :legacy_title
      t.string :title, null: false
      t.datetime :meeting_at, null: false
      t.string :location
      t.text :description
      t.text :review
      t.boolean :reserve_exempt_default, null: false, default: false
      t.references :fiscal_period, foreign_key: { on_delete: :nullify }
      t.references :created_by, foreign_key: { to_table: :users, on_delete: :nullify }

      t.timestamps
    end

    add_index :meetings, :meeting_at
    add_index :meetings, :location

    create_table :meeting_photos do |t|
      t.references :meeting, null: false, foreign_key: { on_delete: :cascade }
      t.string :source_url
      t.string :file_path
      t.string :caption
      t.integer :sort_order, null: false, default: 0

      t.timestamps
    end

    create_table :meeting_attendances do |t|
      t.references :meeting, null: false, foreign_key: { on_delete: :cascade }
      t.references :member, null: false, foreign_key: { on_delete: :cascade }
      t.boolean :reserve_exempt, null: false, default: false
      t.text :note

      t.timestamps
    end

    add_index :meeting_attendances, [:meeting_id, :member_id], unique: true

    create_table :book_requests do |t|
      t.references :member, foreign_key: { on_delete: :nullify }
      t.string :title, null: false
      t.string :author
      t.string :publisher
      t.decimal :price, precision: 12, scale: 2
      t.string :request_status
      t.string :cover_url
      t.string :link_url
      t.text :comment
      t.string :rating
      t.date :requested_on
      t.decimal :additional_payment, precision: 12, scale: 2
      t.references :fiscal_period, foreign_key: { on_delete: :nullify }

      t.timestamps
    end

    add_index :book_requests, :request_status
    add_index :book_requests, :requested_on
  end
end
