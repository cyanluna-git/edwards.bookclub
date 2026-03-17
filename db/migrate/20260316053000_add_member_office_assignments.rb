class AddMemberOfficeAssignments < ActiveRecord::Migration[8.1]
  def change
    create_table :member_office_assignments do |t|
      t.references :member, null: false, foreign_key: { on_delete: :cascade }
      t.references :created_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :office_type, null: false
      t.string :location
      t.date :effective_from, null: false
      t.date :effective_to
      t.text :note
      t.string :source_system
      t.string :source_key

      t.timestamps
    end

    add_index :member_office_assignments,
              [ :office_type, :location, :effective_from ],
              name: "index_member_office_assignments_on_office_scope_and_start"
    add_index :member_office_assignments,
              [ :member_id, :office_type, :location, :effective_from ],
              unique: true,
              name: "index_member_office_assignments_on_member_scope_and_start"
    add_index :member_office_assignments,
              [ :source_system, :source_key ],
              unique: true,
              where: "source_key IS NOT NULL",
              name: "index_member_office_assignments_on_source_system_and_source_key"
  end
end
