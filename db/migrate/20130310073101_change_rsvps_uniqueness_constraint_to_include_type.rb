class ChangeRsvpsUniquenessConstraintToIncludeType < ActiveRecord::Migration
  def up
    add_index :rsvps, [:user_id, :event_id, :user_type], name: "index_rsvps_on_user_id_and_event_id_and_event_type", unique: true
  end

  def down
    remove_index :rsvps, name: "index_rsvps_on_user_id_and_event_id_and_event_type"
  end
end
