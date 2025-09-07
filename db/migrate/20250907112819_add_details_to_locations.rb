class AddDetailsToLocations < ActiveRecord::Migration[8.0]
  def up
    add_column :locations, :status, :string unless column_exists?(:locations, :status)
    add_column :locations, :representative_name, :string unless column_exists?(:locations, :representative_name)
    add_column :locations, :representative_email, :string unless column_exists?(:locations, :representative_email)
    add_column :locations, :email, :string unless column_exists?(:locations, :email)
    add_column :locations, :phone, :string unless column_exists?(:locations, :phone)
    add_column :locations, :date_of_birth, :date unless column_exists?(:locations, :date_of_birth)
    add_column :locations, :ndis_number, :string unless column_exists?(:locations, :ndis_number)
    add_column :locations, :funding, :string unless column_exists?(:locations, :funding)
    add_column :locations, :plan_manager_email, :string unless column_exists?(:locations, :plan_manager_email)
    add_column :locations, :interview_info, :text unless column_exists?(:locations, :interview_info)
    add_column :locations, :schedule_info, :text unless column_exists?(:locations, :schedule_info)
    add_column :locations, :gender, :string unless column_exists?(:locations, :gender)
    add_column :locations, :lives_with, :string unless column_exists?(:locations, :lives_with)
    add_column :locations, :pets, :string unless column_exists?(:locations, :pets)
    add_column :locations, :activities_of_interest, :text unless column_exists?(:locations, :activities_of_interest)
    add_column :locations, :tasks, :text unless column_exists?(:locations, :tasks)
  end

  def down
    # Do not remove :status as it may have existed before this migration
    remove_column :locations, :representative_name if column_exists?(:locations, :representative_name)
    remove_column :locations, :representative_email if column_exists?(:locations, :representative_email)
    remove_column :locations, :email if column_exists?(:locations, :email)
    remove_column :locations, :phone if column_exists?(:locations, :phone)
    remove_column :locations, :date_of_birth if column_exists?(:locations, :date_of_birth)
    remove_column :locations, :ndis_number if column_exists?(:locations, :ndis_number)
    remove_column :locations, :funding if column_exists?(:locations, :funding)
    remove_column :locations, :plan_manager_email if column_exists?(:locations, :plan_manager_email)
    remove_column :locations, :interview_info if column_exists?(:locations, :interview_info)
    remove_column :locations, :schedule_info if column_exists?(:locations, :schedule_info)
    remove_column :locations, :gender if column_exists?(:locations, :gender)
    remove_column :locations, :lives_with if column_exists?(:locations, :lives_with)
    remove_column :locations, :pets if column_exists?(:locations, :pets)
    remove_column :locations, :activities_of_interest if column_exists?(:locations, :activities_of_interest)
    remove_column :locations, :tasks if column_exists?(:locations, :tasks)
  end
end
