require "spec_helper"

describe Tag do
  describe "validations and creation" do
    it "creates a tag with required fields" do
      tag = Tag.create!(tag: "testtag", description: "Test Tag")
      expect(tag).to be_persisted
      expect(tag.tag).to eq("testtag")
    end

    it "has unique tag names" do
      Tag.create!(tag: "unique", description: "First")
      expect {
        Tag.create!(tag: "unique", description: "Second")
      }.to raise_error
    end
  end

  describe "#hotness_mod" do
    it "defaults to 0.0 when not set" do
      tag = Tag.create!(tag: "neutral", description: "Neutral tag")
      expect(tag.hotness_mod).to eq(0.0)
    end

    it "can have positive hotness_mod" do
      tag = Tag.create!(tag: "hot", description: "Hot tag", hotness_mod: 1.5)
      expect(tag.hotness_mod).to eq(1.5)
    end

    it "can have negative hotness_mod" do
      tag = Tag.create!(tag: "cold", description: "Cold tag", hotness_mod: -2.0)
      expect(tag.hotness_mod).to eq(-2.0)
    end
  end

  describe "#valid_for?" do
    let(:regular_user) { User.make! }
    let(:moderator) { User.make!(is_moderator: true) }

    it "allows anyone to use regular tags" do
      tag = Tag.create!(tag: "public", description: "Public tag")
      expect(tag.valid_for?(regular_user)).to eq(true)
      expect(tag.valid_for?(moderator)).to eq(true)
    end

    it "allows only moderators to use privileged tags" do
      tag = Tag.create!(tag: "modonly", description: "Mod only", privileged: true)
      expect(tag.valid_for?(regular_user)).to eq(false)
      expect(tag.valid_for?(moderator)).to eq(true)
    end
  end

  describe "#privileged?" do
    it "returns false for regular tags" do
      tag = Tag.create!(tag: "regular", description: "Regular")
      expect(tag.privileged?).to eq(false)
    end

    it "returns true for privileged tags" do
      tag = Tag.create!(tag: "priv", description: "Privileged", privileged: true)
      expect(tag.privileged?).to eq(true)
    end
  end

  describe "#inactive?" do
    it "returns false for active tags" do
      tag = Tag.create!(tag: "active", description: "Active tag", inactive: false)
      expect(tag.inactive?).to eq(false)
    end

    it "returns true for inactive tags" do
      tag = Tag.create!(tag: "old", description: "Old tag", inactive: true)
      expect(tag.inactive?).to eq(true)
    end
  end

  describe ".active scope" do
    it "returns only active tags" do
      active = Tag.create!(tag: "active", description: "Active", inactive: false)
      inactive = Tag.create!(tag: "inactive", description: "Inactive", inactive: true)

      expect(Tag.active).to include(active)
      expect(Tag.active).not_to include(inactive)
    end
  end

  describe "#is_media?" do
    it "returns true for media tags" do
      media = Tag.create!(tag: "video", description: "Video", is_media: true)
      expect(media.is_media?).to eq(true)
    end

    it "returns false for non-media tags" do
      normal = Tag.create!(tag: "programming", description: "Programming")
      expect(normal.is_media?).to eq(false)
    end
  end

  describe "story associations" do
    it "has many taggings" do
      tag = Tag.create!(tag: "test", description: "Test")
      story = Story.make!(tags_a: ["test"])

      expect(tag.taggings.count).to be > 0
    end

    it "has many stories through taggings" do
      tag = Tag.create!(tag: "ruby", description: "Ruby")
      story = Story.make!(tags_a: ["ruby"])

      expect(tag.stories).to include(story)
    end
  end

  describe "#to_param" do
    it "uses tag name as URL parameter" do
      tag = Tag.create!(tag: "urltest", description: "URL Test")
      expect(tag.to_param).to eq("urltest")
    end
  end

  describe "tag filtering" do
    it "prevents stories from having only media tags" do
      media_tag = Tag.create!(tag: "video", description: "Video", is_media: true)

      expect {
        Story.make!(tags_a: ["video"])
      }.to raise_error
    end

    it "allows stories with mix of media and non-media tags" do
      Tag.create!(tag: "audio", description: "Audio", is_media: true)
      normal_tag = Tag.find_by(tag: "tag1") || Tag.create!(tag: "tag1", description: "Normal")

      expect {
        Story.make!(tags_a: ["tag1", "audio"])
      }.not_to raise_error
    end
  end

  describe "hotness impact on stories" do
    it "affects story hotness calculation" do
      hot_tag = Tag.create!(tag: "trending", description: "Trending", hotness_mod: -1.0)
      cold_tag = Tag.create!(tag: "boring", description: "Boring", hotness_mod: 1.0)

      story_hot = Story.make!(title: "hot story", tags_a: ["trending"])
      story_cold = Story.make!(title: "cold story", tags_a: ["boring"])

      # Verify hotness_mod affects the calculation
      expect(story_hot.calculated_hotness).not_to eq(story_cold.calculated_hotness)
    end
  end
end
