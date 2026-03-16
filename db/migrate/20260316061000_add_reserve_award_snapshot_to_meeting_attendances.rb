class AddReserveAwardSnapshotToMeetingAttendances < ActiveRecord::Migration[8.1]
  def change
    change_table :meeting_attendances do |t|
      t.integer :awarded_points
      t.integer :override_points
      t.string :awarded_policy_role
      t.datetime :awarded_at
    end
  end
end
