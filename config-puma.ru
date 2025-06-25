require ::File.expand_path('../config/environment',  __FILE__)

url_root = Redmine::Utils.relative_url_root.presence || '/'

map url_root do
  run RedmineApp::Application
end
