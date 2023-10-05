# frozen_string_literal: true

require File.dirname(__FILE__) + '/lib/acts_as_searchable'
ApplicationRecord.send(:include, Redmine::Acts::Searchable)
