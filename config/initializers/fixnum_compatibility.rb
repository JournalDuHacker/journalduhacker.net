# Compatibility fix for Machinist gem with Ruby 3.3+
# Fixnum and Bignum were unified into Integer in Ruby 2.4
# This provides backwards compatibility for the machinist gem
unless defined?(Fixnum)
  Fixnum = Integer
end

unless defined?(Bignum)
  Bignum = Integer
end
