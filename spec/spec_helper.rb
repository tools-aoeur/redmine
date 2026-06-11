# frozen_string_literal: true

ENV['RAILS_ENV'] ||= 'test'

# load simplecov
if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start 'rails' do
    coverage_dir 'tmp/coverage'
    # exclude core dirs coverage
    add_filter do |file|
      file.filename.include?('/lib/plugins/') ||
        file.filename.exclude?('/plugins/')
    end
  end
end

# load rails/redmine
require_relative '../config/environment'

# Rails 8.0 timezone preservation configuration
# This setting ensures timezone offset preservation when converting to time
ActiveSupport.to_time_preserves_timezone = true

require Rails.root.join('test/object_helpers').expand_path(__FILE__)
include ObjectHelpers # rubocop:disable Style/MixinUsage
include Redmine::QuoteReply::Helper  # rubocop:disable Style/MixinUsage

# test gems
require 'rspec/rails'
# require 'rspec/autorun'
require 'rspec/mocks'
require 'rspec/mocks/standalone'

module AssertSelectRoot
  def document_root_element
    html_document.root
  end
end

# rspec base config
RSpec.configure do |config|
  config.mock_with :rspec
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true
  config.fixture_paths = [Rails.root.join('test/fixtures')]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.include AssertSelectRoot, type: :request
  config.before(:each, type: :system) do
    options = {}
    options[:capabilities] = Selenium::WebDriver::Remote::Capabilities.chrome(
      'goog:chromeOptions' => {
        'args' => %w[headless no-sandbox disable-gpu]
      }
    )
    driven_by(
      :selenium, using: :chrome, screen_size: [1024, 900],
                 options: options
    )
  end
end

def with_settings(options, &)
  saved_settings = options.keys.index_with do |k|
    case Setting[k]
    when Symbol, false, true, nil
      Setting[k]
    else
      Setting[k].dup
    end
  end
  options.each { |k, v| Setting[k] = v }
  yield
ensure
  saved_settings&.each { |k, v| Setting[k] = v }
end

def log_user(login, password)
  visit '/my/page'
  expect(page).to have_current_path '/login', ignore_query: true

  click_on("ou s'authentifier par login / mot de passe") if Redmine::Plugin.installed?(:redmine_scn)

  within('#login-form form') do
    fill_in 'username', with: login
    fill_in 'password', with: password
    find('input[name=login]').click
  end
  expect(page).to have_current_path '/my/page', ignore_query: true
end

def assert_mail_body_match(expected, mail, message = nil)
  if expected.is_a?(String)
    expect(mail_body(mail)).to include(expected)
  else
    assert_match expected, mail_body(mail), message
  end
end

def assert_mail_body_no_match(expected, mail, message = nil)
  if expected.is_a?(String)
    expect(mail_body(mail)).not_to include expected
  else
    assert_no_match expected, mail_body(mail), message
  end
end

def mail_body(mail)
  mail.parts.first.body.encoded
end

def uploaded_test_file(name, mime)
  fixture_file_upload(Rails.root.join("test/fixtures/files/#{name}"), mime, true)
end
