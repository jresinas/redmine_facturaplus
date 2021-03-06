module Facturaplus
	module CustomFieldsControllerPatch
		def self.included(base) # :nodoc:
			base.extend(ClassMethods)
			base.send(:include, InstanceMethods)

			base.class_eval do
				skip_filter :require_admin, :only => :sync_client_field
				before_filter :authorize_global, :only => :sync_client_field
			end
		end

		module ClassMethods
		end

		module InstanceMethods
			def sync_client_field
				if Setting.plugin_redmine_facturaplus['client_field'].present? or params[:client_custom_field].present? 
				  	client_field_id = params[:client_custom_field] || Setting.plugin_redmine_facturaplus['client_field']
				  	client_field = CustomField.find(client_field_id)

				  	res = Facturaplus::Fp.get_clients(client_field_id)

				  	if res[:result]
				  		client_field.possible_values = (Setting.plugin_redmine_facturaplus['default_clients'].split("\r\n") + res[:options])
						if params[:biller].present?
							render :text => {:type => 'success', :message => l(:'facturaplus.text_sync_success'), :data => FacturaplusClient.get_clients(params[:biller])}.to_json and return if client_field.save
						else
							render :text => {:type => 'success', :message => l(:'facturaplus.text_sync_success'), :data => Setting.plugin_redmine_facturaplus['default_clients'].split("\r\n")}.to_json and return if client_field.save
						end
					end
				end
				render :text => {:type => 'error', :message => l(:'facturaplus.text_sync_fail')}.to_json
			end

			def get_clients
				if params[:biller].present?
					render :text => FacturaplusClient.get_clients(params[:biller]).to_json and return
				else
					render :text => Setting.plugin_redmine_facturaplus['default_clients'].split("\r\n").to_json and return
				end
			end
		end
	end
end

ActionDispatch::Callbacks.to_prepare do
	CustomFieldsController.send(:include, Facturaplus::CustomFieldsControllerPatch)
end
