require "spec_helper"

describe ShortId do
  describe "#generate" do
    it "generates a short id for Story" do
      generator = ShortId.new(Story)
      short_id = generator.generate

      expect(short_id).to be_present
      expect(short_id).to match(/^[a-zA-Z0-9]{1,10}$/)
    end

    it "generates a short id for Comment" do
      generator = ShortId.new(Comment)
      short_id = generator.generate

      expect(short_id).to be_present
      expect(short_id).to match(/^[a-zA-Z0-9]{1,10}$/)
    end

    it "generates unique short ids" do
      generator = ShortId.new(Story)
      id1 = generator.generate
      id2 = generator.generate

      expect(id1).not_to eq(id2)
    end

    it "generates collision-free ids" do
      generator = ShortId.new(Story)
      ids = []

      # Generate multiple IDs
      20.times do
        ids << generator.generate
      end

      # All should be unique
      expect(ids.uniq.length).to eq(ids.length)
    end

    it "generates short ids of reasonable length" do
      generator = ShortId.new(Story)
      short_id = generator.generate

      expect(short_id.length).to be >= 1
      expect(short_id.length).to be <= 10
    end

    it "uses base-36 characters (a-z, 0-9)" do
      generator = ShortId.new(Story)
      short_id = generator.generate

      expect(short_id).to match(/^[a-zA-Z0-9]+$/)
      expect(short_id).not_to include("_")
      expect(short_id).not_to include("-")
      expect(short_id).not_to include(" ")
    end
  end

  describe "integration with Story" do
    it "assigns unique short_id on Story creation" do
      s1 = Story.make!(title: "first")
      s2 = Story.make!(title: "second")

      expect(s1.short_id).to be_present
      expect(s2.short_id).to be_present
      expect(s1.short_id).not_to eq(s2.short_id)
    end

    it "short_id is URL-safe" do
      story = Story.make!(title: "test")

      expect(story.short_id).to match(/^[a-zA-Z0-9]+$/)
    end

    it "can find story by short_id" do
      story = Story.make!(title: "findable")

      found = Story.find_by(short_id: story.short_id)
      expect(found).to eq(story)
    end
  end

  describe "integration with Comment" do
    it "assigns unique short_id on Comment creation" do
      c1 = Comment.make!(comment: "first")
      c2 = Comment.make!(comment: "second")

      expect(c1.short_id).to be_present
      expect(c2.short_id).to be_present
      expect(c1.short_id).not_to eq(c2.short_id)
    end

    it "can find comment by short_id" do
      comment = Comment.make!(comment: "findable")

      found = Comment.find_by(short_id: comment.short_id)
      expect(found).to eq(comment)
    end
  end

  describe "collision handling" do
    it "regenerates on collision" do
      # This test verifies that ShortId handles collisions
      # by attempting to generate a new ID if one already exists

      generator = ShortId.new(Story)

      # Create a story with a short_id
      story = Story.make!(title: "existing")
      existing_id = story.short_id

      # Generate many new IDs - none should match existing
      100.times do
        new_id = generator.generate
        expect(new_id).not_to eq(existing_id) if Story.exists?(short_id: new_id)
      end
    end
  end
end
