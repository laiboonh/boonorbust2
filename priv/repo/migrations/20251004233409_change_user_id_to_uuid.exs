defmodule Boonorbust2.Repo.Migrations.ChangeUserIdToUuid do
  use Ecto.Migration

  def up do
    # Enable pgcrypto extension for UUID generation
    execute("CREATE EXTENSION IF NOT EXISTS pgcrypto")

    # Add new UUID column
    alter table(:users) do
      add :uuid, :uuid, default: fragment("gen_random_uuid()"), null: false
    end

    # Create unique index on UUID
    create unique_index(:users, [:uuid])

    # Populate UUID for existing records (already done via default)
    # Remove old id column and rename uuid to id
    execute("ALTER TABLE users DROP CONSTRAINT users_pkey")
    execute("ALTER TABLE users DROP COLUMN id")
    execute("ALTER TABLE users RENAME COLUMN uuid TO id")
    execute("ALTER TABLE users ADD PRIMARY KEY (id)")
  end

  def down do
    # Add back integer id column
    execute("ALTER TABLE users DROP CONSTRAINT users_pkey")
    execute("ALTER TABLE users RENAME COLUMN id TO uuid")

    alter table(:users) do
      add :id, :serial, primary_key: true
    end

    # Remove UUID column
    drop index(:users, [:uuid])

    alter table(:users) do
      remove :uuid
    end
  end
end
