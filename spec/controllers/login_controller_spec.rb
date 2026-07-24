require "spec_helper"

describe LoginController do
  render_views

  before do
    ActionMailer::Base.deliveries.clear
  end

  describe "password reset flow" do
    it "accepts the link extracted from the encoded email and changes the password" do
      user = User.make!

      post :reset_password, params: {email: user.email}

      reset_url = reset_url_from_last_email
      reset_params = Rack::Utils.parse_query(reset_url.query)

      expect(reset_url.host).to eq(Rails.application.domain)
      expect(reset_url.path).to eq("/login/set_new_password")
      expect(reset_params.fetch("token")).to eq(user.reload.password_reset_token)

      get :set_new_password, params: reset_params

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(user.username)

      post :set_new_password, params: reset_params.merge(
        password: "new secure password",
        password_confirmation: "new secure password"
      )

      expect(response).to redirect_to("/")
      expect(user.reload.authenticate("new secure password")).to eq(user)
      expect(user.password_reset_token).to be_nil
    end

    it "invalidates an earlier link when a newer reset is requested" do
      user = User.make!

      post :reset_password, params: {email: user.email}
      first_reset_params = Rack::Utils.parse_query(reset_url_from_last_email.query)

      post :reset_password, params: {email: user.email}
      latest_reset_params = Rack::Utils.parse_query(reset_url_from_last_email.query)

      expect(first_reset_params.fetch("token")).not_to eq(
        latest_reset_params.fetch("token")
      )

      get :set_new_password, params: first_reset_params
      expect(response).to redirect_to(forgot_password_path)

      get :set_new_password, params: latest_reset_params
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(user.username)
    end
  end

  def reset_url_from_last_email
    email = Mail.read_from_string(ActionMailer::Base.deliveries.last.encoded)
    URI.parse(email.body.decoded[%r{https://\S+}])
  end
end
