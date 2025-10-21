require "spec_helper"

describe BlogPost do
  it "generates a slug from the title" do
    post = BlogPost.make!(title: "Nouveau billet !", slug: "")
    expect(post.slug).to eq("nouveau-billet")
  end

  it "ensures slug uniqueness" do
    BlogPost.make!(title: "Même titre", slug: "")
    other = BlogPost.make!(title: "Même titre", slug: "")

    expect(other.slug).to eq("meme-titre-2")
  end

  it "caches markdown content" do
    post = BlogPost.make!(body: "Un contenu **important**", slug: "")
    expect(post.markeddown_body).to include("<strong>")
  end

  it "returns only non-draft posts that are already published" do
    published = BlogPost.make!(published_at: 1.day.ago, slug: "")
    future = BlogPost.make!(published_at: 1.day.from_now, slug: "")
    draft = BlogPost.make!(published_at: 1.day.ago, draft: true, slug: "")

    expect(published).to be_published
    expect(future).not_to be_published
    expect(draft).not_to be_published

    expect(BlogPost.published).to include(published)
    expect(BlogPost.published).not_to include(future)
    expect(BlogPost.published).not_to include(draft)
  end

  it "builds a human summary" do
    body = "a " * 200
    post = BlogPost.make!(body: body, slug: "")
    expect(post.summary.length).to be <= 281
    expect(post.summary).to end_with("…")
  end
end
