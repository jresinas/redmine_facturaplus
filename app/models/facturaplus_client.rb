class FacturaplusClient < ActiveRecord::Base
	def self.get_clients(biller)
		if Facturaplus::Fp::BILLER_IDS.include?(biller)
			self.where(biller_id: Facturaplus::Fp::BILLER_IDS[biller]).map(&:client_name).sort
		else
			if Setting.plugin_redmine_facturaplus['default_clients'].present?
				return Setting.plugin_redmine_facturaplus['default_clients'].split("\r\n")
			else
				return []
			end
		end
	end
end