require_dependency 'issue'

module Facturaplus
  module IssuePatch
    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
      base.send(:include, InstanceMethods)

      base.class_eval do
        has_one :facturaplus_relation, :dependent => :destroy
        after_save :facturaplus_bill_save, :if => Proc.new{Facturaplus::Fp.requirements?}
        after_destroy :facturaplus_bill_destroy, :if => Proc.new{Facturaplus::Fp.requirements?}
        # Patch to fix error when try to submit a NEW issue form after Rollback in facturaplus_bill_save method
        before_create :patch_new_bill, :if => Proc.new{Facturaplus::Fp.requirements?}
      end
    end

    module ClassMethods
    end

    module InstanceMethods
      def facturaplus_bill_destroy
        results = []
        if self.facturaplus_relation.present?
          results += self.destroy_order
        end

        if (res = results.flatten.find{|r| r[:result].blank?})
          FacturaplusMailer.facturaplus_sync_error(self)
          message = res[:body]['result'].present? ? res[:body]['result'] : I18n.t('facturaplus.text_sync_fail')
          errors[:base] << message
          raise ActiveRecord::Rollback
        end
      end
        
      def patch_new_bill
        @new_bill = true
      end

      def facturaplus_bill_save
        results = []
        biller_field = self.custom_values.find_by(custom_field: Setting.plugin_redmine_facturaplus['biller_field'])
        client_field = self.custom_values.find_by(custom_field: Setting.plugin_redmine_facturaplus['client_field'])
        amount_field = self.custom_values.find_by(custom_field: Setting.plugin_redmine_facturaplus['amount_field'])
        currency_field = self.custom_values.find_by(custom_field: Setting.plugin_redmine_facturaplus['currency_field'])

        if (!biller_field.present? or !client_field.present? or !amount_field.present? or !currency_field.present?) and Setting.plugin_redmine_facturaplus['billers'].include?(biller_field.value)
          # Faltan campos requeridos en el ticket
          errors[:base] << I18n.t('facturaplus.text_fields_missing')
          # Patch to fix error when try to submit a NEW issue form after Rollback in facturaplus_bill_save method
          self.destroy if @new_bill.present?
          raise ActiveRecord::Rollback
        end

        if tracker_id.to_s == Setting.plugin_redmine_facturaplus['bill_tracker'] and !Setting.plugin_redmine_facturaplus['billed_statuses'].include?(status_id.to_s) and Setting.plugin_redmine_facturaplus['billers'].include?(biller_field.value)
          # Es una factura emitada por una empresa con FacturaPlus y está en estado NO facturado
          biller_id = begin Facturaplus::BILLER_IDS[biller_field.value] rescue nil end
          client_id = begin FacturaplusClient.find_by(client_name: client_field.value, biller_id: biller_id).client_id rescue nil end
          amount = begin amount_field.value.to_f rescue nil end
          currency = begin currency_field.value rescue nil end

          if client_id.blank?
            # El cliente (o emisor) elegidos no son validos (el cliente no está registrado en el emisor en FacturaPlus) -> ERROR
            errors[:base] << I18n.t('facturaplus.text_biller_client_not_valid')

            # Patch to fix error when try to submit a NEW issue form after Rollback in facturaplus_bill_save method
            self.destroy if @new_bill.present?

            raise ActiveRecord::Rollback
          end

          if self.facturaplus_relation.present? and (biller_id != self.facturaplus_relation.biller_id or client_id != self.facturaplus_relation.client_id or amount != self.facturaplus_relation.amount or currency != self.facturaplus_relation.currency)
            # Tiene elementos de FacturaPlus asociados pero los datos han cambiado -> borramos los elementos asociados
            results += self.destroy_order
          end

          # -> nos aseguramos que tenga un pedido
          results += self.create_order(biller_id, client_id, amount, currency)
          if Setting.plugin_redmine_facturaplus['billable_statuses'].include?(status_id.to_s)
            # Está en estado facturable -> nos aseguramos que tenga un albarán
            results += self.create_delivery_note(biller_id, client_id, amount, currency)
          elsif self.facturaplus_relation.present? and self.facturaplus_relation.delivery_note_id.present?
            # No está facturable pero tiene un albarán asociado en FacturaPlus -> borrar albarán asociado
            results += self.destroy_delivery_note
          end
        elsif self.facturaplus_relation.present?
          # No es una factura emitada por una empresa con FacturaPlus, pero tiene elementos de FacturaPlus asociados -> borramos los elementos asociados si NO está en estado facturado o NO está emitido por una empresa con FacturaPlus       
          results += self.destroy_order if !Setting.plugin_redmine_facturaplus['billed_statuses'].include?(status_id.to_s) or !Setting.plugin_redmine_facturaplus['billers'].include?(biller_field.value)
        end

        if (res = results.flatten.find{|r| r[:result].blank?})
          FacturaplusMailer.facturaplus_sync_error(self)
          message = res[:body]['result'].present? ? res[:body]['result'] : I18n.t('facturaplus.text_sync_fail')
          errors[:base] << message

          # Patch to fix error when try to submit a NEW issue form after Rollback in facturaplus_bill_save method
          self.destroy if @new_bill.present?

          raise ActiveRecord::Rollback
        end
      end

      def destroy_order
        result = []
        result << destroy_delivery_note
        result << Facturaplus::Fp.delete_order(self) if self.facturaplus_relation.order_id.present?
        self.facturaplus_relation = nil if self.facturaplus_relation.present?
        result
      end

      def destroy_delivery_note
        result = []
        result << Facturaplus::Fp.delete_delivery_note(self) if self.facturaplus_relation.delivery_note_id.present?
        self.facturaplus_relation.delivery_note_id = nil if self.facturaplus_relation.present? and !self.facturaplus_relation.destroyed?
        result
      end

      def create_order(biller_id, client_id, amount, currency)
        result = []
        begin
          self.facturaplus_relation = FacturaplusRelation.new({biller_id: biller_id, client_id: client_id, amount: amount, currency: currency}) if self.facturaplus_relation.blank?
          result << Facturaplus::Fp.set_order(self) if self.facturaplus_relation.order_id.blank?
          result
        rescue
          [{:result => false}]
        end
      end

      def create_delivery_note(biller_id, client_id, amount, currency)
        result = []
        create_order(biller_id, client_id, amount, currency) if self.facturaplus_relation.blank?
        result << Facturaplus::Fp.set_delivery_note(self) if self.facturaplus_relation.delivery_note_id.blank?
        result
      end
    end
  end
end

ActionDispatch::Callbacks.to_prepare do
  Issue.send(:include, Facturaplus::IssuePatch)
end