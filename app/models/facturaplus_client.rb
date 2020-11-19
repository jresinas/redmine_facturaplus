class FacturaplusClient < ActiveRecord::Base
	def self.get_clients(biller)
		biller_association = SageAssociation.find_by_source_id_and_data_type(biller, 'Biller')
		if biller_association.present?
			self.where(biller_id: biller_association.target_code).map(&:client_name).sort
		else
			if Setting.plugin_redmine_facturaplus['default_clients'].present?
				return Setting.plugin_redmine_facturaplus['default_clients'].split("\r\n")
			else
				return []
			end
		end
	end
end