class AddXeroEmployeeIdToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :xero_employee_id, :string
  end
end
