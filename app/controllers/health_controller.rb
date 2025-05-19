class HealthController < ApplicationController
  skip_before_action :authenticate_user!, only: [:check]
  before_action :restrict_to_local, only: [:check]

  private

  def restrict_to_local
    allowed_ips = ['127.0.0.1', '::1']
    unless allowed_ips.include?(request.remote_ip)
      render json: { status: 'error', message: 'Access denied' }, status: :forbidden
    end
  end

  # Perform a lightweight database connection check
  def check
    ActiveRecord::Base.connection.active?
    render json: { status: 'ok' }, status: :ok
  rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::NoDatabaseError
    render json: { status: 'error', message: 'Database connection failed' }, status: :service_unavailable
  end
end
