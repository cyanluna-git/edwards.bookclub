class AddImportSourceKeys < ActiveRecord::Migration[8.1]
  def change
    {
      members: :member,
      meetings: :meeting,
      meeting_attendances: :meeting_attendance,
      meeting_photos: :meeting_photo,
      book_requests: :book_request
    }.each_key do |table_name|
      add_column table_name, :source_system, :string
      add_column table_name, :source_key, :string
      add_index table_name, [:source_system, :source_key],
                unique: true,
                where: "source_key IS NOT NULL",
                name: "index_#{table_name}_on_source_system_and_source_key"
    end
  end
end
