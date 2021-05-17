require "net/http"
require "uri"

module Facturaplus
	class Fp
		@@fplog ||= Logger.new("#{Rails.root}/log/fp.log")
		# BILLER_IDS = {"Emergya S.C.A." => 31, "Emergya Ingeniería S.L." => 32}
		# SERVICE_IDS = {"Desarrollo" => "01", "Consultoría" => "02", "Licencias" => "03", "Mantenimiento" => "04", "BPO" => "05", "Subcontratación" => "06", "Otros" =>"07", "Soporte" => "08", "Hardware" => "09", "I+D" => "10", "Gestión de producción" => "11", "Estructura de Producción" => "12", "Estructura" => "13", "No Clasificado" => "14", "AWS" => "15", "GCP" => "16", "GMP" => "17", "GSuite" => "18", "Alquiler" => "99"}
		BUSINESS_DEPARTMENT_NAME = "RED"

		def self.requirements?
			Setting.plugin_redmine_facturaplus['bill_tracker'].present? and 
				Setting.plugin_redmine_facturaplus['biller_field'].present? and 
				Setting.plugin_redmine_facturaplus['service_field'].present? and
				Setting.plugin_redmine_facturaplus['currency_field'].present? and
				Setting.plugin_redmine_facturaplus['client_field'].present? and
				Setting.plugin_redmine_facturaplus['billable_statuses'].present? and
				Setting.plugin_redmine_facturaplus['billed_statuses'].present?
		end

		def self.get_clients(field)
			res = facturaplus_request(get_endpoint('get_clients_endpoint'), {}, 'get')

			if res[:result]
				FacturaplusClient.transaction do
					FacturaplusClient.destroy_all
					# save_success = FacturaplusClient.create(res[:body]['results'].map{|c| {client_name: c['name'], biller_id: c['codeEmisor'].to_i, client_id: c['code'].to_i}})
					save_success = FacturaplusClient.create(res[:body]['results'].map{|c| {client_name: c['nombre'], biller_id: c['codigoEmpresa'].to_i, client_id: c['codigoCliente'].to_i}})
					res[:options] = res[:body]['results'].map{|c| c['nombre']}.uniq.sort
					raise ActiveRecord::Rollback if !save_success
				end
			end

			res
		end

		def self.set_order(issue)
			params = {
				:facturacion => get_amount(issue).to_f,
				:iva => get_vat(issue).to_f,
				:idTicket => issue.id.to_s,
				:fechaFacturacion => get_billing_date(issue),
				:asunto => issue.subject.gsub('–','-'),
				:empresaEmisora => get_biller_id(issue).to_s,
				:cliente => get_client_id(issue).to_s.rjust(6,'0'),
				:codDivisa => get_currency_id(issue),
				#:valDivisaEuro => get_currency_exchange(issue),
				:cref => get_service_id(issue),
				#:areaGeografica => get_market_name(issue),
				:unidadNegocio => get_business_unit_id(issue),
				:lineaNegocio => get_business_line_id(issue),
				:departamentoNegocio => get_business_department_name(issue),
				:serie => get_order_serial_code(issue),
				:ejercicioPedido => get_order_year(issue)
			}
			res = facturaplus_request(get_endpoint('set_order_endpoint'), params, 'post')

			if res[:result]
				if issue.facturaplus_relation.present?
					issue.facturaplus_relation[:order_id] = res[:body]['num']
					issue.facturaplus_relation.save
				else
					issue.facturaplus_relation = FacturaplusRelation.new(order_id: res[:body]['num'])
				end
			end

			res
		end

		def self.set_delivery_note(issue)
			params = {
				:facturacion => get_amount(issue).to_f,
				:numPedidoCliente => issue.facturaplus_relation[:order_id],
				:iva => get_vat(issue).to_f,
				:idTicket => issue.id.to_s,
				:fechaFacturacion => get_billing_date(issue),
				:asunto => issue.subject.gsub('–','-'),
				:empresaEmisora => get_biller_id(issue).to_s,
				:cliente => get_client_id(issue).to_s.rjust(6,'0'),
				:codDivisa => get_currency_id(issue),
				#:valDivisaEuro => get_currency_exchange(issue),
				:cref => get_service_id(issue),
				#:areaGeografica => get_market_name(issue),
				:unidadNegocio => get_business_unit_id(issue),
				:lineaNegocio => get_business_line_id(issue),
				:departamentoNegocio => get_business_department_name(issue),
				:serie => get_order_serial_code(issue),
				:ejercicioPedido => get_order_year(issue)
			}
			# res = facturaplus_request(get_endpoint('set_delivery_note_endpoint'), params, 'post')
			res = facturaplus_request(get_endpoint('serve_order_to_delivery_note_endpoint'), params, 'post')

			if res[:result]
				if issue.facturaplus_relation.present?
					issue.facturaplus_relation[:delivery_note_id] = res[:body]['num']
					issue.facturaplus_relation.save
				# else
				# 	issue.facturaplus_relation = FacturaplusRelation.new(delivery_note_id: res[:body]['num'])
				end
			end

			res
		end

		def self.delete_order(issue)
			params = {
				:numPedido => issue.facturaplus_relation[:order_id],
				# :empresaEmisora => get_biller_id(issue).to_s
				:empresaEmisora => issue.facturaplus_relation[:biller_id].to_s
			}
			res = facturaplus_request(get_endpoint('delete_order_endpoint'), params, 'delete')

			if res[:result]
				# issue.facturaplus_relation = nil if issue.facturaplus_relation.present?
			end

			res
		end

		def self.delete_delivery_note(issue)
			params = {
				:numAlbaran => issue.facturaplus_relation[:delivery_note_id],
				# :empresaEmisora => get_biller_id(issue).to_s,
				:empresaEmisora => issue.facturaplus_relation[:biller_id].to_s,
				:numPedido => issue.facturaplus_relation[:order_id]
			}
			res = facturaplus_request(get_endpoint('delete_delivery_note_endpoint'), params, 'delete')

			if res[:result]
				if issue.facturaplus_relation.present?
					# issue.facturaplus_relation[:delivery_note_id] = nil 
					# issue.facturaplus_relation.save
				end
			end

			res
		end

		def self.invoice_exists?(issue)
			params = {
				:numAlbaran => issue.facturaplus_relation[:delivery_note_id],
				:empresaEmisora => issue.facturaplus_relation[:biller_id].to_s,
				:numPedido => issue.facturaplus_relation[:order_id]
			}
			res = facturaplus_request(get_endpoint('has_existing_invoice_endpoint'), params, 'get')

			if res[:result] and Setting.plugin_redmine_facturaplus['billable_statuses'].include?(issue.status.id.to_s)
				issue.update_attribute('status', IssueStatus.find(Setting.plugin_redmine_facturaplus['billed_statuses']).first) #Facturado
			end
		end

		private
		def self.get_biller_name(issue)
			begin
				Enumeration.find(issue.custom_values.find_by(custom_field_id: Setting.plugin_redmine_facturaplus['biller_field']).value).name
			rescue
				nil
			end
		end

		def self.get_client_name(issue)
			begin
				issue.custom_values.find_by(custom_field_id: Setting.plugin_redmine_facturaplus['client_field']).value
			rescue
				nil
			end
		end

		def self.get_biller_id(issue)
			begin
				SageAssociation.find_by(source_id: issue.custom_values.find_by(custom_field_id: Setting.plugin_redmine_facturaplus['biller_field']).value, data_type: 'Biller').target_code
			rescue
				nil
			end
		end

		def self.get_client_id(issue)
			begin
				FacturaplusClient.find_by(client_name: get_client_name(issue), biller_id: get_biller_id(issue)).client_id
			rescue
				nil
			end
		end

		def self.get_amount(issue)
			begin
				issue.custom_values.find_by(custom_field_id: Setting.plugin_redmine_facturaplus['amount_field']).value
			rescue
				nil
			end
		end

		def self.get_vat(issue)
			begin
				issue.custom_values.find_by(custom_field_id: Setting.plugin_redmine_facturaplus['vat_field']).value
			rescue
				nil
			end
		end

		def self.get_billing_date(issue)
			begin
				issue.custom_values.find_by(custom_field_id: Setting.plugin_redmine_facturaplus['billing_date_field']).value
			rescue
				nil
			end
		end

		def self.get_currency_id(issue)
			begin
				SageAssociation.find_by(source_id: issue.custom_values.find_by(custom_field_id: Setting.plugin_redmine_facturaplus['currency_field']).value, data_type: 'Currency').target_code
			rescue
				nil
			end
		end

		def self.get_currency_exchange(issue)
			begin
				Currency.find(get_currency_id(issue)).exchange.to_f
			rescue
				nil
			end
		end

		def self.get_service_name(issue)
			begin
				Enumeration.find(issue.project.custom_values.find_by(custom_field_id: Setting.plugin_redmine_facturaplus['service_field']).value).name
			rescue
				nil
			end
		end

		def self.get_service_id(issue)
			begin
				SageAssociation.find_by(source_id: issue.project.custom_values.find_by(custom_field_id: Setting.plugin_redmine_facturaplus['service_field']).value, data_type: 'Article').target_code
			rescue
				nil
			end
		end

		def self.get_market_name(issue)
			begin
				issue.project.custom_values.find_by(custom_field_id: Setting.plugin_redmine_facturaplus['market_field']).value
			rescue
				nil
			end
		end

		def self.get_business_unit_name(issue)
			begin
				Enumeration.find(issue.project.custom_values.find_by(custom_field_id: Setting.plugin_redmine_facturaplus['business_unit_field']).value).name
			rescue
				nil
			end
		end

		def self.get_business_unit_id(issue)
			begin
				SageAssociation.find_by(source_id: issue.project.custom_values.find_by(custom_field_id: Setting.plugin_redmine_facturaplus['business_unit_field']).value, data_type: 'Section').target_code
			rescue
				nil
			end
		end

		def self.get_business_line_name(issue)
			begin
				Enumeration.find(issue.project.custom_values.find_by(custom_field_id: Setting.plugin_redmine_facturaplus['business_line_field']).value).name
			rescue
				nil
			end
		end

		def self.get_business_line_id(issue)
			begin
				SageAssociation.find_by(source_id: issue.project.custom_values.find_by(custom_field_id: Setting.plugin_redmine_facturaplus['business_line_field']).value, data_type: 'SageProject').target_code
			rescue
				nil
			end
		end

		def self.get_business_department_name(issue)
			begin
				BUSINESS_DEPARTMENT_NAME
			rescue
				nil
			end
		end

		def self.get_order_serial_code(issue)
			begin
				SageAssociation.get_project_serial_from_business_line(issue.project.custom_values.find_by(custom_field_id: Setting.plugin_redmine_facturaplus['business_line_field']).value).target_code
			rescue
				nil
			end
		end

		def self.get_order_year(issue)
			begin
				Date.strptime(issue.custom_values.find_by(custom_field_id: Setting.plugin_redmine_facturaplus['billing_date_field']).value, '%Y-%m-%d').year
			rescue
				nil
			end
		end

		def self.get_endpoint(action)
			if Setting.plugin_redmine_facturaplus[action].present? and Setting.plugin_redmine_facturaplus['protocol'].present? and Setting.plugin_redmine_facturaplus['domain'].present?
				protocol = Setting.plugin_redmine_facturaplus['protocol']
				domain = Setting.plugin_redmine_facturaplus['domain'].gsub(/\/$/, '')
				path = Setting.plugin_redmine_facturaplus[action].gsub(/^\//, '')
				return protocol+"://"+domain+'/'+path
			else
				return nil
			end
		end

		def self.facturaplus_request(url, parameters, method)
			begin
				if Setting.plugin_redmine_facturaplus['devel_mode'].present?
					code = 200
					result = true
					body = {}
				elsif url.present?
				    uri = URI.parse(url)

				    case method
				       when 'get'
				       	req = Net::HTTP::Get.new(url+"?"+parameters.to_query)
				       when 'post'
				       	req = Net::HTTP::Post.new(url)
				       	req.set_form_data(parameters)
				       when 'put'
				       	req = Net::HTTP::Put.new(url)
				       	req.set_form_data(parameters)
				       when 'delete'
				       	req = Net::HTTP::Delete.new(url+"?"+parameters.to_query)
				    end

				    if Setting.plugin_redmine_facturaplus['user'].present? and Setting.plugin_redmine_facturaplus['pssw'].present?
				    	req.basic_auth Setting.plugin_redmine_facturaplus['user'], Setting.plugin_redmine_facturaplus['pssw']
					end

				    res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => uri.scheme == 'https', :verify_mode => OpenSSL::SSL::VERIFY_NONE) do |http|
				      	@@fplog.info("Send #{method.upcase} to #{url} with #{parameters}")
				      	http.request(req)
				    end
				    @@fplog.info("Receive #{res.code} with #{res.body}")

				    code = res.code
				    result = (res.code.to_i >= 200 and res.code.to_i < 300) or (res.code.to_i == 304)
				    body = res.body.present? ? JSON.parse(res.body.force_encoding('UTF-8')) : {}
				else
					code = 404
					result = false
					body = {}
				end
			rescue
				code = 503
				result = false
				body = {}
			end

		    {:code => code, :result => result, :body => body}
		end
	end
end
