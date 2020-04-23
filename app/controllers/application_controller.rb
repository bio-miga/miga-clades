require "miga"
require "redcarpet"

class ApplicationController < ActionController::Base
  #before_filter :block_ip_addresses
  
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  include SessionsHelper

  protected
    
    # Block known attacker IP ranges
    def block_ip_addresses
      ip = current_ip_address
      head :unauthorized if ip =~ /^46\.229\.168\./
    end

    # Client IP address
    def current_ip_address
      request.env["HTTP_X_REAL_IP"] || request.env["REMOTE_ADDR"]
    end

  private
  
  # Confirms a logged-in user
  def logged_in_user
    unless logged_in?
      store_location
      flash[:danger] = 'Please log in'
      redirect_to login_url
    end
  end

  # Confirms an admin user
  def admin_user
    unless current_user.admin?
      flash[:danger] = 'You don\'t have enough privileges to access this page'
      redirect_to(root_url)
    end
  end
end
