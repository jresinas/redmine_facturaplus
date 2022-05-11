require 'csv'
namespace :facturaplus do
	desc "List of Redmine-Sage 200c clients"
	task :sage_clients => :environment do
		headers = ["Nombre Cliente facturacion en Redmine","id Empresa Redmine","id Cliente en Sage","id combinado iris"]
		results = [headers]

		facturaplus_clients = FacturaplusClient.all

		facturaplus_clients.each do |fc|
			result = []
			#Nombre Cliente
			result << fc.client_name
			#id Empresa Redmine
			result << ((emp = SageAssociation.find_by(target_code: fc.biller_id, data_type: 'Biller')).present? ? emp.source_id : '' )
			#id Cliente Sage
			result << fc.client_id
			#id combinado Iris
			result << fc.iris_code
			
			results << result
		end

		generate_csv("sage_redmine_clients", results)
	end

	def generate_csv(filename, data)
		CSV.open("public/"+filename+".csv","w",:col_sep => ';',:encoding=>'UTF-8') do |file|
			data.each do |row|
				file << row
			end
		end
	end
end