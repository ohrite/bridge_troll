class Location < ActiveRecord::Base
  has_many :events

  attr_accessible :name, :address_1, :address_2, :city, :state, :zip

  validates_presence_of :name, :address_1, :city
  acts_as_gmappable(process_geocoding: !Rails.env.test?)

  def gmaps4rails_address
    "#{self.address_1}, #{self.city}, #{self.state}, #{self.zip}" 
  end
end