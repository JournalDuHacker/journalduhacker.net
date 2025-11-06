class HealthController < ApplicationController
  # Skip authentication and traffic tracking for health checks
  skip_before_action :authenticate_user
  skip_before_action :increase_traffic_counter
  skip_before_action :verify_authenticity_token

  # Liveness probe: Check if Rails process is responding
  # Does NOT check database to avoid cascade restarts in Kubernetes
  def live
    render json: {status: "ok"}, status: :ok
  end

  # Readiness probe: Check if application is ready to serve traffic
  # Checks database connectivity
  def ready
    # Check database connection
    ActiveRecord::Base.connection.execute("SELECT 1")

    render json: {
      status: "ready",
      checks: {
        database: "ok"
      }
    }, status: :ok
  rescue => e
    render json: {
      status: "unavailable",
      checks: {
        database: "error"
      },
      error: e.message
    }, status: :service_unavailable
  end
end
