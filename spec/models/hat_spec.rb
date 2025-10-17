require "spec_helper"

describe Hat do
  let(:user) { User.make! }
  let(:granter) { User.make!(is_moderator: true) }

  describe "creation and validation" do
    it "creates a hat with required fields" do
      hat = Hat.create!(
        user_id: user.id,
        granted_by_user_id: granter.id,
        hat: "Developer",
        link: "https://example.com"
      )

      expect(hat).to be_persisted
      expect(hat.user).to eq(user)
      expect(hat.granted_by_user).to eq(granter)
    end

    it "requires user" do
      hat = Hat.new(
        granted_by_user_id: granter.id,
        hat: "Developer"
      )

      expect(hat.valid?).to eq(false)
      expect(hat.errors[:user]).to be_present
    end

    it "requires granted_by_user" do
      hat = Hat.new(
        user_id: user.id,
        hat: "Developer"
      )

      expect(hat.valid?).to eq(false)
      expect(hat.errors[:granted_by_user]).to be_present
    end
  end

  describe "associations" do
    it "belongs to user" do
      hat = Hat.create!(
        user_id: user.id,
        granted_by_user_id: granter.id,
        hat: "Developer"
      )

      expect(hat.user).to be_a(User)
      expect(hat.user.id).to eq(user.id)
    end

    it "belongs to granted_by_user" do
      hat = Hat.create!(
        user_id: user.id,
        granted_by_user_id: granter.id,
        hat: "Developer"
      )

      expect(hat.granted_by_user).to be_a(User)
      expect(hat.granted_by_user.id).to eq(granter.id)
    end
  end

  describe "#destroy_by_user_with_reason" do
    it "creates moderation log when revoking hat" do
      hat = Hat.create!(
        user_id: user.id,
        granted_by_user_id: granter.id,
        hat: "Developer"
      )

      initial_mod_count = Moderation.count

      hat.destroy_by_user_with_reason(granter, "No longer applicable")

      expect(Moderation.count).to eq(initial_mod_count + 1)
      mod = Moderation.last
      expect(mod.action).to include("Revoked hat")
      expect(mod.action).to include("Developer")
      expect(mod.action).to include("No longer applicable")
    end

    it "destroys the hat" do
      hat = Hat.create!(
        user_id: user.id,
        granted_by_user_id: granter.id,
        hat: "Developer"
      )

      expect {
        hat.destroy_by_user_with_reason(granter, "Test")
      }.to change { Hat.count }.by(-1)
    end
  end

  describe "#to_html_label" do
    it "generates HTML for hat with link" do
      hat = Hat.create!(
        user_id: user.id,
        granted_by_user_id: granter.id,
        hat: "Developer",
        link: "https://example.com"
      )

      html = hat.to_html_label
      expect(html).to include("Developer")
      expect(html).to include("<span class=\"crown\">")
    end

    it "generates HTML for hat without link" do
      hat = Hat.create!(
        user_id: user.id,
        granted_by_user_id: granter.id,
        hat: "Moderator",
        link: ""
      )

      html = hat.to_html_label
      expect(html).to include("Moderator")
      expect(html).to include("<span class=\"crown\">")
    end

    it "escapes HTML in hat name" do
      hat = Hat.create!(
        user_id: user.id,
        granted_by_user_id: granter.id,
        hat: "<script>alert('xss')</script>",
        link: ""
      )

      html = hat.to_html_label
      expect(html).not_to include("<script>")
      expect(html).to include("&lt;script&gt;")
    end

    it "creates clickable link for HTTP URLs" do
      hat = Hat.create!(
        user_id: user.id,
        granted_by_user_id: granter.id,
        hat: "Developer",
        link: "https://github.com/username"
      )

      html = hat.to_html_label
      expect(html).to include("href=\"https://github.com/username\"")
      expect(html).to include("target=\"_blank\"")
    end
  end

  describe "moderation logging" do
    it "logs hat creation as moderation action" do
      initial_mod_count = Moderation.count

      Hat.create!(
        user_id: user.id,
        granted_by_user_id: granter.id,
        hat: "Developer",
        link: "https://example.com"
      )

      expect(Moderation.count).to eq(initial_mod_count + 1)
      mod = Moderation.last
      expect(mod.action).to include("Granted hat")
      expect(mod.action).to include("Developer")
      expect(mod.moderator_user_id).to eq(granter.id)
    end

    it "includes link in moderation log when present" do
      Hat.create!(
        user_id: user.id,
        granted_by_user_id: granter.id,
        hat: "Developer",
        link: "https://example.com"
      )

      mod = Moderation.last
      expect(mod.action).to include("https://example.com")
    end
  end
end
