class AddI18nFields < ActiveRecord::Migration[4.2]
  def self.up
    add_column(:custom_fields, "i18n", :text)
    add_column(:enumerations, "i18n", :text)
    add_column(:issue_statuses, "i18n", :text)
    add_column(:roles, "i18n", :text)
    add_column(:trackers, "i18n", :text)
  end

  def self.down
    remove_column(:custom_fields, "i18n")
    remove_column(:enumerations, "i18n")
    remove_column(:issue_statuses, "i18n")
    remove_column(:roles, "i18n")
    remove_column(:trackers, "i18n")
  end
end
