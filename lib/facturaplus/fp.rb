require "net/http"
require "uri"

module Facturaplus
	BILLER_IDS = {"Emergya S.C.A." => 31, "Emergya Ingeniería S.L." => 32}
	SERVICE_IDS = {"Desarrollo" => "01", "Consultorias" => "02", "Licencias" => "03", "Mantenimiento" => "04", "BPO" => "05", "Subcontratación" => "06", "Otros" =>"07", "Alquiler" => "99"}

	class Fp
		def self.requirements?
			Setting.plugin_redmine_facturaplus['bill_tracker'].present? and 
				Setting.plugin_redmine_facturaplus['biller_field'].present? and 
				Setting.plugin_redmine_facturaplus['billers'].present? and
				Setting.plugin_redmine_facturaplus['client_field'].present? and
				Setting.plugin_redmine_facturaplus['billable_statuses'].present? and
				Setting.plugin_redmine_facturaplus['billed_statuses'].present?
		end

		def self.get_clients(field)
			res = facturaplus_request(Setting.plugin_redmine_facturaplus['get_clients_endpoint'], {}, 'get')

			if res[:result]
				FacturaplusClient.transaction do
					FacturaplusClient.destroy_all
					save_success = FacturaplusClient.create(res[:body]['results'].map{|c| {client_name: c['name'], biller_id: c['codeEmisor'].to_i, client_id: c['code'].to_i}})
					res[:options] = res[:body]['results'].map{|c| c['name']}.uniq.sort
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
				:valDivisaEuro => get_currency_exchange(issue),
				:cref => get_service_id(issue)
			}
			res = facturaplus_request(Setting.plugin_redmine_facturaplus['set_order_endpoint'], params, 'post')

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
				:valDivisaEuro => get_currency_exchange(issue),
				:cref => get_service_id(issue)
			}
			res = facturaplus_request(Setting.plugin_redmine_facturaplus['set_delivery_note_endpoint'], params, 'post')

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
			res = facturaplus_request(Setting.plugin_redmine_facturaplus['delete_order_endpoint'], params, 'delete')

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
			res = facturaplus_request(Setting.plugin_redmine_facturaplus['delete_delivery_note_endpoint'], params, 'delete')

			if res[:result]
				if issue.facturaplus_relation.present?
					# issue.facturaplus_relation[:delivery_note_id] = nil 
					# issue.facturaplus_relation.save
				end
			end

			res
		end

		private
		def self.get_biller_name(issue)
			begin
				issue.custom_values.find_by(custom_field_id: Setting.plugin_redmine_facturaplus['biller_field']).value
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
				Facturaplus::BILLER_IDS[get_biller_name(issue)]
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
				(get_currency_id(issue) == "1") ? issue.custom_values.find_by(custom_field_id: Setting.plugin_redmine_facturaplus['vat_field']).value : 0.0
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
				issue.custom_values.find_by(custom_field_id: Setting.plugin_redmine_facturaplus['currency_field']).value
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
				issue.project.custom_values.find_by(custom_field_id: Setting.plugin_redmine_facturaplus['service_field']).value
			rescue
				nil
			end
		end

		def self.get_service_id(issue)
			begin
				Facturaplus::SERVICE_IDS[get_service_name(issue)]
			rescue
				nil
			end
		end

		def self.facturaplus_request(url, parameters, method)
			begin
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

			    res = Net::HTTP.start(uri.hostname, uri.port) do |http|
			      http.request(req)
			    end

			    code = res.code
			    result = (res.code.to_i >= 200 and res.code.to_i < 300) or (res.code.to_i == 304)
			    body = res.body.present? ? JSON.parse(res.body.force_encoding('UTF-8')) : {}
			rescue
				code = 503
				result = false
				body = {}
			end

		    {:code => code, :result => result, :body => body}
		end
	end
end