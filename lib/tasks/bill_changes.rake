namespace :facturaplus do
	task :bill_changes => :environment do
		FacturaplusMailer.bill_changes(Date.today).deliver
	end
end