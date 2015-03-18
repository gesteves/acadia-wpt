require_relative 'app'

namespace :wpt do
  task :run do
    wpt = Acadia::WPT.new
    wpt.run_test
  end

  task :get do
    wpt = Acadia::WPT.new
    wpt.get_test
  end
end