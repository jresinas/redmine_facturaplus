class FacturaplusMailer < Mailer
	def facturaplus_sync_error(issue)
	    @issue = issue
	    mail to: Setting.plugin_redmine_facturaplus['emails'], subject: l(:'facturaplus.email_subject')
	end
end