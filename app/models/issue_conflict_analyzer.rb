# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

class IssueConflictAnalyzer
  class AttributeField
    attr_reader :key

    def initialize(key)
      @key = key
    end

    def submitted_value(issue_attributes)
      issue_attributes[key]
    end

    def current_value(issue)
      issue.attributes[key]
    end

    def baseline_value(current, details)
      details.reverse_each { |detail| current = detail.old_value }
      current
    end

    def matches_detail?(detail)
      detail.property == 'attr' && detail.prop_key == key
    end

    def merge_into(merged, issue_attributes)
      merged[key] = issue_attributes[key]
    end

    def label
      translation_key = "field_#{key.delete_suffix('_id')}"
      if I18n.exists?(translation_key)
        I18n.t(translation_key.to_sym)
      else
        key.humanize
      end
    end
  end

  class CustomFieldField
    attr_reader :key

    def initialize(key)
      @key = key
    end

    def submitted_value(issue_attributes)
      (issue_attributes['custom_field_values'] || {})[key]
    end

    def current_value(issue)
      issue.custom_field_value(key)
    end

    def baseline_value(current, details)
      custom_field = CustomField.find_by(id: key)
      details.reverse_each do |detail|
        current = if custom_field&.multiple?
                    reverse_multiple_value(Array(current), detail)
                  else
                    detail.old_value
                  end
      end
      current
    end

    def matches_detail?(detail)
      detail.property == 'cf' && detail.prop_key == key
    end

    def merge_into(merged, issue_attributes)
      merged['custom_field_values'] ||= {}
      merged['custom_field_values'][key] = submitted_value(issue_attributes)
    end

    def label
      custom_field = CustomField.find_by(id: key)
      custom_field ? custom_field.name : "Custom field #{key}"
    end

    private

    def reverse_multiple_value(values, detail)
      values = values.map(&:to_s)

      if detail.old_value.nil? && detail.value.present?
        values.delete_at(values.index(detail.value) || values.length)
      elsif detail.value.nil? && detail.old_value.present?
        values << detail.old_value
      elsif detail.value.present?
        index = values.index(detail.value)
        if index
          values[index] = detail.old_value
        elsif detail.old_value.present?
          values << detail.old_value
        end
      end

      values
    end
  end

  def initialize(issue, issue_attributes, last_journal_id)
    @issue = issue
    @issue_attributes = normalize_issue_attributes(issue_attributes)
    @last_journal_id = last_journal_id
  end

  def actual_conflicting_fields
    submitted_changed_fields.select { |field| conflicting_field?(field) }
  end

  def auto_merge_attributes
    merged = {}
    submitted_changed_fields.reject { |field| conflicting_field?(field) }.each do |field|
      field.merge_into(merged, @issue_attributes)
    end
    merged
  end

  def self.field_from_detail(detail)
    return if detail.prop_key.blank?

    case detail.property
    when 'attr' then AttributeField.new(detail.prop_key)
    when 'cf' then CustomFieldField.new(detail.prop_key)
    end
  end

  private

  def normalize_issue_attributes(issue_attributes)
    issue_attributes ||= {}
    issue_attributes = issue_attributes.to_unsafe_hash if issue_attributes.respond_to?(:to_unsafe_hash)
    issue_attributes = issue_attributes.stringify_keys

    custom_field_values = issue_attributes['custom_field_values']
    if custom_field_values.respond_to?(:stringify_keys)
      issue_attributes['custom_field_values'] = custom_field_values.stringify_keys
    end

    issue_attributes
  end

  def submitted_fields
    @submitted_fields ||= candidate_fields.select do |field|
      normalize(field.submitted_value(@issue_attributes)) != normalize(field.baseline_value(field.current_value(current_issue_state), details_for(field)))
    end
  end

  def submitted_changed_fields
    @submitted_changed_fields ||= submitted_fields.select do |field|
      normalize(field.submitted_value(@issue_attributes)) != normalize(field.current_value(current_issue_state))
    end
  end

  def conflicting_field?(field)
    conflicting_fields.any? { |c| c.key == field.key && c.instance_of?(field.class) }
  end

  def conflicting_fields
    @conflicting_fields ||= conflict_details
      .filter_map { |detail| self.class.field_from_detail(detail) }
      .uniq { |f| [f.class, f.key] }
  end

  def candidate_fields
    @candidate_fields ||= begin
      attr_keys = (@issue_attributes.keys.map(&:to_s) - %w(lock_version custom_field_values))
                    .select { |key| @issue_attributes.key?(key) }
      cf_keys = (@issue_attributes['custom_field_values'] || {}).keys.map(&:to_s)

      attr_keys.map { |k| AttributeField.new(k) } + cf_keys.map { |k| CustomFieldField.new(k) }
    end
  end

  def details_for(field)
    conflict_details.select { |detail| field.matches_detail?(detail) }
  end

  def conflict_details
    @conflict_details ||= @issue.journals_after(@last_journal_id).flat_map(&:details)
  end

  def current_issue_state
    @current_issue_state ||= Issue.find(@issue.id)
  end

  def normalize(value)
    if value.is_a?(Array)
      value.filter_map do |item|
        next if item.blank?

        item.to_s
      end.sort
    else
      value.presence&.to_s
    end
  end
end
