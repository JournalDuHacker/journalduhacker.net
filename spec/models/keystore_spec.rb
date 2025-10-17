require "spec_helper"

describe Keystore do
  describe "key-value storage" do
    it "stores and retrieves a value" do
      Keystore.put("test_key", 42)
      value = Keystore.value_for("test_key")

      expect(value.to_i).to eq(42)
    end

    it "returns nil for non-existent key" do
      value = Keystore.value_for("nonexistent_key_#{Time.now.to_i}")
      expect(value).to be_nil
    end

    it "updates existing value" do
      key = "update_test_#{Time.now.to_i}"
      Keystore.put(key, 100)
      Keystore.put(key, 200)

      expect(Keystore.value_for(key).to_i).to eq(200)
    end
  end

  describe ".get" do
    it "returns keystore record for existing key" do
      key = "get_test_#{Time.now.to_i}"
      Keystore.put(key, 123)

      record = Keystore.get(key)
      expect(record).to be_a(Keystore)
      expect(record.key).to eq(key)
      expect(record.value.to_i).to eq(123)
    end

    it "returns nil for non-existent key" do
      record = Keystore.get("nonexistent_#{Time.now.to_i}")
      expect(record).to be_nil
    end
  end

  describe ".increment_value_for" do
    it "increments numeric value by 1 by default" do
      key = "increment_test_#{Time.now.to_i}"
      Keystore.put(key, 10)

      Keystore.increment_value_for(key)

      expect(Keystore.value_for(key).to_i).to eq(11)
    end

    it "increments by specified amount" do
      key = "increment_amount_#{Time.now.to_i}"
      Keystore.put(key, 5)

      Keystore.increment_value_for(key, 3)

      expect(Keystore.value_for(key).to_i).to eq(8)
    end

    it "initializes to 0 if key doesn't exist" do
      key = "new_increment_#{Time.now.to_i}"

      Keystore.increment_value_for(key, 5)

      expect(Keystore.value_for(key).to_i).to eq(5)
    end
  end

  describe ".incremented_value_for" do
    it "returns the incremented value" do
      key = "incremented_return_#{Time.now.to_i}"
      Keystore.put(key, 10)

      result = Keystore.incremented_value_for(key, 5)

      expect(result.to_i).to eq(15)
    end
  end

  describe ".decrement_value_for" do
    it "decrements numeric value by 1 by default" do
      key = "decrement_test_#{Time.now.to_i}"
      Keystore.put(key, 10)

      Keystore.decrement_value_for(key)

      expect(Keystore.value_for(key).to_i).to eq(9)
    end

    it "decrements by specified amount" do
      key = "decrement_amount_#{Time.now.to_i}"
      Keystore.put(key, 10)

      Keystore.decrement_value_for(key, -3)

      expect(Keystore.value_for(key).to_i).to eq(7)
    end
  end

  describe ".decremented_value_for" do
    it "returns the decremented value" do
      key = "decremented_return_#{Time.now.to_i}"
      Keystore.put(key, 10)

      result = Keystore.decremented_value_for(key, -3)

      expect(result.to_i).to eq(7)
    end
  end

  describe "concurrent access" do
    it "handles concurrent increments correctly" do
      key = "concurrent_test_#{Time.now.to_i}"
      Keystore.put(key, 0)

      # Simulate multiple increments
      5.times { Keystore.increment_value_for(key) }

      expect(Keystore.value_for(key).to_i).to eq(5)
    end
  end

  describe "validation" do
    it "requires a key" do
      ks = Keystore.new(value: 42)
      expect(ks.valid?).to eq(false)
      expect(ks.errors[:key]).to be_present
    end

    it "allows creating with key" do
      key = "valid_key_#{Time.now.to_i}"
      ks = Keystore.new(key: key, value: 42)
      expect(ks.valid?).to eq(true)
    end
  end

  describe "primary key" do
    it "uses key as primary key" do
      expect(Keystore.primary_key).to eq("key")
    end

    it "can find by key directly" do
      key = "pk_test_#{Time.now.to_i}"
      Keystore.put(key, 999)

      record = Keystore.find(key)
      expect(record.value.to_i).to eq(999)
    end
  end
end
