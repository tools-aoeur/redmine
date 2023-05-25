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

module Redmine
  module Info
    class << self
      def app_name; 'Redmine' end
      def url; 'https://www.redmine.org/' end
      def help_url; 'https://www.redmine.org/guide' end

      def versioned_name
        deploy_info_file = File.join(Rails.root, 'deploy.info')
        deployment_tag = begin
          File.read(deploy_info_file).strip
        rescue
          nil
        end
        deployment_tag ? "#{app_name} (deployment: #{deployment_tag})" : "#{app_name} #{Redmine::VERSION}"
      end

      def database_server
        db_connection = ActiveRecord::Base.connection
        adapter = db_connection.adapter_name.downcase
        if adapter.include?('postgresql')
          db_connection.execute("SELECT version()").first[0]
        elsif adapter.include?('mysql')
          "MySQL #{db_connection.execute('SELECT VERSION()').first[0]}"
        else
          'unknown'
        end
      end

      def web_server
        if defined?(Puma::Const::PUMA_VERSION)
          "Puma #{Puma::Const::PUMA_VERSION}"
        else
          'unknown'
        end
      end

      def session_store
        if Rails.application.config.session_store.name == "ActionDispatch::Session::RedisStore"
          options = Rails.application.config.session_options[:servers].first
          server_info = Redis.new(options).info
          if server_info['server_name'].eql?('valkey')
            "Valkey #{server_info['valkey_version']}"
          else
            "Redis #{server_info['redis_version']}"
          end
        else
          'unknown'
        end
      end

      def environment
        s = +"Environment:\n"
        s << [
          ["Redmine version", Redmine::VERSION],
          ["Ruby version", "#{RUBY_VERSION}-p#{RUBY_PATCHLEVEL} (#{RUBY_RELEASE_DATE}) [#{RUBY_PLATFORM}]"],
          ["Rubygems version", Gem::VERSION],
          ["Bundler version", Bundler::VERSION],
          ["Rails version", Rails::VERSION::STRING],
          ["Environment", Rails.env],
          ["Database adapter", ActiveRecord::Base.connection.adapter_name],
          ["Database server", database_server],
          ["Web server", web_server],
          ["Session store", session_store],
          ["Cache store", Rails.cache.class.name],
          ["Mailer queue", ActionMailer::MailDeliveryJob.queue_adapter.class.name],
          ["Mailer delivery", ActionMailer::Base.delivery_method]
        ].map {|info| "  %-30s %s" % info}.join("\n") + "\n"

        theme_string = ''
        theme_string += (Setting.ui_theme.blank? ? 'Default' : Setting.ui_theme.capitalize)
        unless Setting.ui_theme.blank? ||
          Redmine::Themes.theme(Setting.ui_theme).nil? ||
          !Redmine::Themes.theme(Setting.ui_theme).javascripts.include?('theme')
          theme_string += ' (includes JavaScript)'
        end

        s << "Redmine settings:\n"
        s << [
          ["Redmine theme", theme_string]
        ].map {|settings| "  %-30s %s" % settings}.join("\n") + "\n"

        s << "SCM:\n"
        Redmine::Scm::Base.all.each do |scm|
          scm_class = "Repository::#{scm}".constantize
          if scm_class.scm_available
            s << "  %-30s %s\n" % [scm, scm_class.scm_version_string]
          end
        end

        s << "Redmine plugins:\n"
        plugins = Redmine::Plugin.all

        # Build a hash of plugin IDs to their hashes from plugins.info
        plugins_info_file = File.join(Rails.root, 'plugins.info')
        plugin_hashes = {}
        if File.file?(plugins_info_file)
          File.read(plugins_info_file).split(',').each do |entry|
            id, hash = entry.split(':')
            plugin_hashes[id.strip] = hash.strip if id && hash
          end
        end

        if plugins.any?
          s << plugins.map do |plugin|
            hash_or_version = plugin_hashes[plugin.id.to_s] || plugin.version.to_s
            "  %-30s %s" % [plugin.id.to_s, hash_or_version]
          end.join("\n")
        else
          s << "  no plugin installed"
        end
      end
    end
  end
end
