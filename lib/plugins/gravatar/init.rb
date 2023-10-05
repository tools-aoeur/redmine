# frozen_string_literal: true

require File.dirname(__FILE__) + '/lib/gravatar'
ApplicationRecord.send :include, GravatarHelper::PublicMethods
