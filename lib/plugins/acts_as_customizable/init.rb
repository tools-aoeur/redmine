# frozen_string_literal: true

require File.dirname(__FILE__) + '/lib/acts_as_customizable'
ApplicationRecord.send(:include, Redmine::Acts::Customizable)
