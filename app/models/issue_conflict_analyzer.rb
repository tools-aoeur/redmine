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
  def initialize(issue, issue_attributes, last_journal_id)
    @issue = issue
    @issue_attributes = normalize_issue_attributes(issue_attributes)
    @last_journal_id = last_journal_id
  end

  def actual_conflicting_issue_change_keys
    conflicting_attribute_keys, conflicting_custom_field_keys = conflicting_issue_change_keys
    submitted_attribute_keys, submitted_custom_field_keys = submitted_issue_change_keys

    actual_attribute_keys = conflicting_attribute_keys.select do |key|
      submitted_attribute_keys.include?(key) &&
        normalize_conflict_value(issue_attribute_value(@issue_attributes, key)) != normalize_conflict_value(current_issue_attribute_value(key))
    end

    custom_field_values = @issue_attributes['custom_field_values'] || {}
    actual_custom_field_keys = conflicting_custom_field_keys.select do |key|
      submitted_custom_field_keys.include?(key) &&
        normalize_conflict_value(issue_custom_field_value(custom_field_values, key)) != normalize_conflict_value(current_issue_custom_field_value(key))
    end

    [actual_attribute_keys.uniq, actual_custom_field_keys.uniq]
  end

  def auto_merge_attributes
    merged_attributes = {}
    submitted_attribute_keys, submitted_custom_field_keys = submitted_issue_change_keys

    conflicting_attribute_keys, conflicting_custom_field_keys = actual_conflicting_issue_change_keys

    submitted_attribute_keys.each do |key|
      next if conflicting_attribute_keys.include?(key)
      next if normalize_conflict_value(issue_attribute_value(@issue_attributes, key)) == normalize_conflict_value(current_issue_attribute_value(key))

      merged_attributes[key] = issue_attribute_value(@issue_attributes, key)
    end

    custom_field_values = @issue_attributes['custom_field_values'] || {}
    safe_custom_field_values = submitted_custom_field_keys.each_with_object({}) do |key, values|
      next if conflicting_custom_field_keys.include?(key)
      next if normalize_conflict_value(issue_custom_field_value(custom_field_values, key)) == normalize_conflict_value(current_issue_custom_field_value(key))

      values[key] = issue_custom_field_value(custom_field_values, key)
    end

    merged_attributes['custom_field_values'] = safe_custom_field_values if safe_custom_field_values.present?

    merged_attributes
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

  def conflicting_issue_change_keys
    conflicting_attribute_keys, conflicting_custom_field_keys = conflicting_change_details
    [conflicting_attribute_keys.uniq, conflicting_custom_field_keys.uniq]
  end

  def submitted_issue_change_keys
    custom_field_values = @issue_attributes['custom_field_values'] || {}

    relevant_attribute_keys = conflicting_relevant_issue_attribute_keys.select do |key|
      @issue_attributes.key?(key)
    end

    submitted_attribute_keys = relevant_attribute_keys.select do |key|
      normalize_conflict_value(issue_attribute_value(@issue_attributes, key)) != normalize_conflict_value(baseline_issue_attribute_value(key))
    end

    submitted_custom_field_keys = custom_field_values.keys.map(&:to_s).select do |key|
      normalize_conflict_value(issue_custom_field_value(custom_field_values, key)) != normalize_conflict_value(baseline_issue_custom_field_value(key))
    end

    [submitted_attribute_keys.uniq, submitted_custom_field_keys.uniq]
  end

  def conflicting_relevant_issue_attribute_keys
    @conflicting_relevant_issue_attribute_keys ||= (@issue_attributes.keys.map(&:to_s) - %w(lock_version custom_field_values))
  end

  def conflicting_change_details
    return @conflicting_change_details if defined?(@conflicting_change_details)

    conflicting_attribute_keys = []
    conflicting_custom_field_keys = []

    @issue.journals_after(@last_journal_id).each do |journal|
      journal.details.each do |detail|
        if detail.property == 'attr' && detail.prop_key.present?
          conflicting_attribute_keys << detail.prop_key
        elsif detail.property == 'cf' && detail.prop_key.present?
          conflicting_custom_field_keys << detail.prop_key
        end
      end
    end

    @conflicting_change_details = [conflicting_attribute_keys, conflicting_custom_field_keys]
  end

  def issue_attribute_value(issue_attributes, key)
    issue_attributes[key.to_s]
  end

  def issue_custom_field_value(custom_field_values, key)
    custom_field_values[key.to_s]
  end

  def baseline_issue_attribute_value(key)
    value = current_issue_attribute_value(key)
    conflicting_attribute_details(key).reverse_each do |detail|
      value = detail.old_value
    end
    value
  end

  def baseline_issue_custom_field_value(key)
    custom_field = CustomField.find_by(id: key)
    value = current_issue_custom_field_value(key)

    conflicting_custom_field_details(key).reverse_each do |detail|
      if custom_field&.multiple?
        value = reverse_multiple_custom_field_detail(Array(value), detail)
      else
        value = detail.old_value
      end
    end

    value
  end

  def current_issue_attribute_value(key)
    current_issue_state.attributes[key]
  end

  def current_issue_custom_field_value(key)
    current_issue_state.custom_field_value(key)
  end

  def current_issue_state
    @current_issue_state ||= Issue.find(@issue.id)
  end

  def conflicting_attribute_details(key)
    conflict_details.select do |detail|
      detail.property == 'attr' && detail.prop_key == key
    end
  end

  def conflicting_custom_field_details(key)
    conflict_details.select do |detail|
      detail.property == 'cf' && detail.prop_key == key
    end
  end

  def conflict_details
    @conflict_details ||= @issue.journals_after(@last_journal_id).flat_map(&:details)
  end

  def reverse_multiple_custom_field_detail(values, detail)
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

  def normalize_conflict_value(value)
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
