# frozen_string_literal: true

require File.dirname(__FILE__) + '/lib/acts_as_activity_provider'
ApplicationRecord.send(:include, Redmine::Acts::ActivityProvider)
