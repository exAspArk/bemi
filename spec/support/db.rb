require 'active_record'

ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: 'test.db'
)

class InitBemiTables < Bemi::Storage.migration
end

InitBemiTables.migrate(:down)
InitBemiTables.migrate(:up)
