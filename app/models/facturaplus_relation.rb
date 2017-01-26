class FacturaplusRelation < ActiveRecord::Base
	belongs_to :issue

	def remove_delivery_note
		self.delivery_note_id = nil
		self.save
	end
end