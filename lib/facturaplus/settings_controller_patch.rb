module Facturaplus
  module SettingsControllerPatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      base.class_eval do
        skip_filter :authorize, :check_if_login_required, :require_admin, :verify_authenticity_token, :only => [:get_clients, :set_order, :set_delivery_note, :delete_order, :delete_delivery_note]
      end
    end

    module ClassMethods
    end

    module InstanceMethods
      def show_tracker_custom_fields
        render :layout => false, :partial => 'get_tracker_custom_fields'
      end

      def show_list_options
        render :layout => false, :partial => 'get_list_options'
      end

      def show_tracker_statuses
        render :layout => false, :partial => 'get_tracker_statuses'
      end
    end
  end
end

ActionDispatch::Callbacks.to_prepare do
  require_dependency 'settings_controller'
  SettingsController.send(:include, Facturaplus::SettingsControllerPatch)
end
