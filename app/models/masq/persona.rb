module Masq
  class Persona < ActiveRecord::Base
    belongs_to :account
    has_many :sites, dependent: :destroy

    validates_presence_of :account
    validates_presence_of :title
    validates_uniqueness_of :title, scope: :account_id

    before_destroy :check_deletable!

    # attr_protected :account_id, :deletable

    class << self
      def properties
        mappings.keys
      end

      def attribute_name_for_type_uri(type_uri)
        prop = mappings.detect { |i| i[1].include?(type_uri) }
        prop ? prop[0] : nil
      end

      # Mappings for SReg names and AX Type URIs to attributes
      def mappings
        Masq::Engine.config.masq["attribute_mappings"]
      end
    end

    public

    # Returns the personas attribute for the given SReg name or AX Type URI
    def property(type)
      prop = Persona.mappings.detect { |i| i[1].include?(type) }
      prop ? send(prop[0]).to_s : nil
    end

    def date_of_birth
      "#{dob_year? ? dob_year : "0000"}-#{dob_month? ? dob_month.to_s.rjust(2, "0") : "00"}-#{dob_day? ? dob_day.to_s.rjust(2, "0") : "00"}"
    end

    def fullname=(name)
      self.firstname, self.surname = name.to_s.split(" ")
      self.surname ||= firstname
      self[:fullname] = name
    end

    def date_of_birth=(dob)
      res = dob.split("-")
      self.dob_year = res[0]
      self.dob_month = res[1]
      self.dob_day = res[2]
    end

    protected

    def check_deletable!
      raise ActiveRecord::RecordNotDestroyed unless deletable
    end
  end
end
