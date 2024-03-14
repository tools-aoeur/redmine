module TranslatableAttributes
  extend ActiveSupport::Concern

  included do
    store :i18n, coder: JSON
  end

  module ClassMethods
    def i18n(*attr_names)
      attr_names.each do |attr_name|
        define_method :"i18n_#{attr_name}" do
          return self.send(attr_name) if self.i18n.blank?

          locale = User.current.language.to_s
          self.i18n&.dig(attr_name, locale) || self.send(attr_name)
        end
      end
    end
  end
end
