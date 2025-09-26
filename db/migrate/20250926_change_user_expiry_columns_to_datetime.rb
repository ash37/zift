class ChangeUserExpiryColumnsToDatetime < ActiveRecord::Migration[8.0]
  def up
    # Convert blank strings to NULL to avoid cast errors
    execute <<~SQL
      UPDATE users SET blue_expiry = NULL WHERE blue_expiry = '';
      UPDATE users SET yellow_expiry = NULL WHERE yellow_expiry = '';
    SQL

    # Change column types using explicit casts
    execute <<~SQL
      ALTER TABLE users
        ALTER COLUMN blue_expiry TYPE timestamp USING blue_expiry::timestamp,
        ALTER COLUMN yellow_expiry TYPE timestamp USING yellow_expiry::timestamp;
    SQL
  end

  def down
    # Convert back to string in ISO 8601 without timezone
    execute <<~SQL
      ALTER TABLE users
        ALTER COLUMN blue_expiry TYPE varchar USING COALESCE(TO_CHAR(blue_expiry, 'YYYY-MM-DD" "HH24:MI:SS'), ''),
        ALTER COLUMN yellow_expiry TYPE varchar USING COALESCE(TO_CHAR(yellow_expiry, 'YYYY-MM-DD" "HH24:MI:SS'), '');
    SQL
  end
end

