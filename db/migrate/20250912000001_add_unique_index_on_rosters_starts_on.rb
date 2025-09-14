class AddUniqueIndexOnRostersStartsOn < ActiveRecord::Migration[8.0]
  def up
    # Collapse duplicate rosters per starts_on while preserving shifts.
    # 1) For each starts_on, keep the lowest id as canonical; repoint shifts from dup rosters to the keeper.
    # 2) Delete the now-orphaned duplicate rosters.
    execute <<~SQL
      WITH keepers AS (
        SELECT MIN(id) AS keep_id, starts_on
        FROM rosters
        GROUP BY starts_on
      ), dups AS (
        SELECT r.id AS dup_id, r.starts_on, k.keep_id
        FROM rosters r
        JOIN keepers k ON r.starts_on = k.starts_on
        WHERE r.id <> k.keep_id
      )
      UPDATE shifts s
      SET roster_id = d.keep_id
      FROM dups d
      WHERE s.roster_id = d.dup_id;
    SQL

    execute <<~SQL
      WITH keepers AS (
        SELECT MIN(id) AS keep_id, starts_on
        FROM rosters
        GROUP BY starts_on
      )
      DELETE FROM rosters r
      USING keepers k
      WHERE r.starts_on = k.starts_on
        AND r.id <> k.keep_id;
    SQL

    add_index :rosters, :starts_on, unique: true, name: "index_rosters_on_starts_on_unique" unless index_exists?(:rosters, :starts_on, name: "index_rosters_on_starts_on_unique")
  end

  def down
    remove_index :rosters, name: "index_rosters_on_starts_on_unique" if index_exists?(:rosters, :starts_on, name: "index_rosters_on_starts_on_unique")
  end
end
