require 'active_record'

ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: 'test.db'
)

InitBemiTables = Class.new(Bemi.generate_migration)

InitBemiTables.migrate(:down)
InitBemiTables.migrate(:up)
