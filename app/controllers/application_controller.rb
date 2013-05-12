class ApplicationController < ActionController::Base
  protect_from_forgery

  before_filter :configure_devise_parameters, if: :devise_controller?

  def validate_organizer!
    @event = Event.find(params[:event_id])
    organizer = @event.organizer?(current_user) || current_user.admin?

    unless organizer
      redirect_to events_path
      false
    end
  end

  def after_sign_in_path_for(resource)
    params[:return_to] || super
  end

  protected

  def configure_devise_parameters
    devise_parameter_sanitizer.for(:sign_in) do |user|
      user.permit(
        :email,
        :password,
        :password_confirmation,
        :reset_password_token,
        :remember_me
      )
    end

    devise_parameter_sanitizer.for(:sign_up) do |user|
      user.permit(
        :first_name,
        :last_name,
        :email,
        :password,
        :password_confirmation,
        :time_zone
      )
    end

    devise_parameter_sanitizer.for(:account_update) do |user|
      user.permit(
        :first_name,
        :last_name,
        :email,
        :current_password,
        :password,
        :password_confirmation,
        :time_zone
      )
    end
  end
end
