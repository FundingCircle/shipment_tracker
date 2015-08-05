class CreateTickets < ActiveRecord::Migration
  def change
    create_table :tickets do |t|
      t.string :key
      t.string :summary
      t.string :status
      t.text :urls, array: true
      t.datetime :event_created_at
    end
  end
end
