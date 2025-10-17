class Keystore < ApplicationRecord
  self.primary_key = "key"

  validates_presence_of :key

  def self.get(key)
    where(key: key).first
  end

  def self.value_for(key)
    where(key: key).first.try(:value)
  end

  def self.put(key, value)
    if Keystore.connection.adapter_name == "SQLite"
      Keystore.connection.execute("INSERT OR REPLACE INTO " \
        "#{Keystore.table_name} (`key`, `value`) VALUES " \
        "(#{q(key)}, #{q(value)})")
    elsif /Mysql/.match?(Keystore.connection.adapter_name)
      Keystore.connection.execute("INSERT INTO #{Keystore.table_name} (" \
        "`key`, `value`) VALUES (#{q(key)}, #{q(value)}) ON DUPLICATE KEY " \
        "UPDATE `value` = #{q(value)}")
    else
      kv = find_or_create_key_for_update(key, value)
      kv.value = value
      kv.save!
    end

    true
  end

  def self.increment_value_for(key, amount = 1)
    incremented_value_for(key, amount)
  end

  def self.incremented_value_for(key, amount = 1)
    Keystore.transaction do
      if Keystore.connection.adapter_name == "SQLite"
        Keystore.connection.execute("INSERT OR IGNORE INTO " \
          "#{Keystore.table_name} (`key`, `value`) VALUES " \
          "(#{q(key)}, 0)")
        Keystore.connection.execute("UPDATE #{Keystore.table_name} " \
          "SET `value` = `value` + #{q(amount)} WHERE `key` = #{q(key)}")
      elsif /Mysql/.match?(Keystore.connection.adapter_name)
        Keystore.connection.execute("INSERT INTO #{Keystore.table_name} (" \
          "`key`, `value`) VALUES (#{q(key)}, #{q(amount)}) ON DUPLICATE KEY " \
          "UPDATE `value` = `value` + #{q(amount)}")
      else
        kv = find_or_create_key_for_update(key, 0)
        kv.value = kv.value.to_i + amount
        kv.save!
        return kv.value
      end

      value_for(key)
    end
  end

  def self.find_or_create_key_for_update(key, init = nil)
    loop do
      kv = lock(true).where(key: key).first
      return kv if kv

      begin
        create! do |kv|
          kv.key = key
          kv.value = init
          kv.save!
        end
      rescue ActiveRecord::RecordNotUnique
        nil
      end
    end
  end

  def self.decrement_value_for(key, amount = -1)
    increment_value_for(key, amount)
  end

  def self.decremented_value_for(key, amount = -1)
    incremented_value_for(key, amount)
  end
end
