# Monkey patch for Ruby 3.x compatibility with Machinist
# In Ruby 3.x, Fixnum was merged into Integer
# This allows old code that references Fixnum to still work

unless defined?(Fixnum) # rubocop:disable Lint/UnifiedInteger
  Fixnum = Integer # rubocop:disable Lint/UnifiedInteger
end
