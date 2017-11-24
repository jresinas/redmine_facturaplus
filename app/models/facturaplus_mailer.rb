CF_FACTURACION = 152;
CF_FECHA_FACTURACION = 153;

class FacturaplusMailer < Mailer
	def facturaplus_sync_error(issue)
	    @issue = issue
	    mail to: Setting.plugin_redmine_facturaplus['emails'], subject: l(:'facturaplus.email_subject')
	end

	def bill_changes(date)
		@facturas = JournalDetail.joins(:journal).where("DATE(journals.created_on) = ? AND journal_details.property = 'cf' AND journal_details.prop_key = ?", date, CF_FACTURACION).group_by{|e| e.journal.journalized_id}.map{|e,v| {:issue => e, :old => v.first.old_value, :new => v.last.value}}
		@fechas = JournalDetail.joins(:journal).where("DATE(journals.created_on) = ? AND journal_details.property = 'cf' AND journal_details.prop_key = ?", Date.today, CF_FECHA_FACTURACION).group_by{|e| e.journal.journalized_id}.map{|e,v| {:issue => e, :old => v.first.old_value, :new => v.last.value}}

	    mail to: Setting.plugin_redmine_facturaplus['emails'], subject: l(:'facturaplus.daily_email_subject')
	end
end