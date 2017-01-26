require 'facturaplus/issue_patch'
require 'facturaplus/settings_controller_patch'
require 'facturaplus/hooks'
require 'facturaplus/custom_fields_controller_patch'

Redmine::Plugin.register :redmine_facturaplus do
  Rails.configuration.after_initialize do
    locale = if Setting.table_exists?
               Setting.default_language
             else
               'en'
             end
    I18n.with_locale(locale) do
      name I18n.t :'facturaplus.plugin_name'
      description I18n.t :'facturaplus.plugin_description'
      author 'Emergya Consultoría'
      version '0.0.1'
    end
  end

  permission :clients_sync, { :custom_fields => [:sync_client_field] }

  settings :default => {}, :partial => 'settings/facturaplus_settings'
end
