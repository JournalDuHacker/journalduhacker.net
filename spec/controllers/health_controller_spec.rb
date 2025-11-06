require "spec_helper"

describe HealthController do
  describe "GET #live" do
    it "returns 200 OK without checking database" do
      get :live
      expect(response.status).to eq(200)
      json_response = JSON.parse(response.body)
      expect(json_response["status"]).to eq("ok")
    end

    it "does not require authentication" do
      get :live
      expect(response.status).to eq(200)
    end
  end

  describe "GET #ready" do
    it "returns 200 OK when database is available" do
      get :ready
      expect(response.status).to eq(200)
      json_response = JSON.parse(response.body)
      expect(json_response["status"]).to eq("ready")
      expect(json_response["checks"]["database"]).to eq("ok")
    end

    it "returns 503 when database is unavailable" do
      allow(ActiveRecord::Base.connection).to receive(:execute).and_raise(ActiveRecord::ConnectionNotEstablished)

      get :ready
      expect(response.status).to eq(503)
      json_response = JSON.parse(response.body)
      expect(json_response["status"]).to eq("unavailable")
      expect(json_response["checks"]["database"]).to eq("error")
    end

    it "does not require authentication" do
      get :ready
      expect(response.status).to eq(200)
    end
  end
end
