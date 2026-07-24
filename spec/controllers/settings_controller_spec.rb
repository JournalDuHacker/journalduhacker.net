require "spec_helper"

describe SettingsController do
  render_views

  describe "GET #twofa_enroll" do
    it "renders the generated QR code" do
      user = User.make!
      session[:u] = user.session_token
      session[:last_authed] = Time.now.to_i

      get :twofa_enroll

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("<svg")
      expect(response.body).to include("otpauth://totp/")
    end
  end
end
