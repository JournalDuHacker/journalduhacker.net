require "spec_helper"

describe User do
  it "has a valid username" do
    expect { User.make!(:username => nil) }.to raise_error
    expect { User.make!(:username => "") }.to raise_error
    expect { User.make!(:username => "*") }.to raise_error

    unique_username = "test_#{Time.now.to_i}_#{rand(1000)}"
    User.make!(:username => unique_username)
    expect { User.make!(:username => unique_username) }.to raise_error
  end

  it "has a valid email address" do
    User.make!(:email => "user@example.com")

    # duplicate
    expect { User.make!(:email => "user@example.com") }.to raise_error

    # bad address
    expect { User.make!(:email => "user@") }.to raise_error
  end

  it "authenticates properly" do
    u = User.make!(:password => "hunter2")

    expect(u.password_digest.length).to be > 20

    expect(u.authenticate("hunter2")).to eq(u)
    expect(u.authenticate("hunteR2")).to eq(false)
  end

  it "gets an error message after registering banned name" do
    expect { User.make!(:username => "admin") }.to raise_error("La validation a échoué : Username is not permitted")
  end

  it "shows a user is banned or not" do
    u = User.make!(:banned)
    user = User.make!
    expect(u.is_banned?).to eq(true)
    expect(user.is_banned?).to eq(false)
  end

  it "shows a user is active or not" do
    u = User.make!(:banned)
    user = User.make!
    expect(u.is_active?).to eq(false)
    expect(user.is_active?).to eq(true)
  end

  it "shows a user is recent or not" do
    user = User.make!(:created_at => Time.now)
    u = User.make!(:created_at => Time.now - 8.days)
    expect(user.is_new?).to eq(true)
    expect(u.is_new?).to eq(false)
  end

  it "unbans a user" do
    u = User.make!(:banned)
    expect(u.unban_by_user!(User.first)).to eq(true)
  end
end
