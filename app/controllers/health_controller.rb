class HealthController < ApplicationController
  # Perform a lightweight database connection check
  def check
    ActiveRecord::Base.connection.active?
    render json: { status: 'ok' }, status: :ok
  rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::NoDatabaseError
    render json: { status: 'error', message: 'Database connection failed' }, status: :service_unavailable
  end
end
