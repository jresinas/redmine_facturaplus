class SageAssociation < ActiveRecord::Base

	def self.get_project_serial_from_business_line(business_line)
		sage_project_association = self.find_by_source_id_and_data_type(business_line, 'SageProject')
		if sage_project_association.present?
			self.find_by_source_id_and_data_type(sage_project_association.id, 'Serial')
		else
			nil
		end
	end

end
