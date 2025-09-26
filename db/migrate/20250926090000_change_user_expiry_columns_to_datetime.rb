class ChangeUserExpiryColumnsToDatetime < ActiveRecord::Migration[8.0]
  def up
    # Change column types using robust casts; handle blanks and date-only strings
    execute <<~SQL
      ALTER TABLE users
        ALTER COLUMN blue_expiry TYPE timestamp USING (
          CASE
            WHEN blue_expiry IS NULL THEN NULL
            WHEN trim(blue_expiry::text) = '' THEN NULL
            WHEN blue_expiry::text ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN (blue_expiry::text || ' 00:00:00')::timestamp
            ELSE blue_expiry::timestamp
          END
        ),
        ALTER COLUMN yellow_expiry TYPE timestamp USING (
          CASE
            WHEN yellow_expiry IS NULL THEN NULL
            WHEN trim(yellow_expiry::text) = '' THEN NULL
            WHEN yellow_expiry::text ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN (yellow_expiry::text || ' 00:00:00')::timestamp
            ELSE yellow_expiry::timestamp
          END
        );
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
