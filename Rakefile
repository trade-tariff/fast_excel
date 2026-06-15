desc "Sync github.com:Paxa/libxlsxwriter to ./libxlsxwriter"
task :sync do
  require 'fileutils'
  FileUtils.rm_rf("./libxlsxwriter")
  system("git clone --depth 10 git@github.com:Paxa/libxlsxwriter.git")
  Dir.chdir("./libxlsxwriter") do
    system("git show --pretty='format:%cd %h' --date=iso --quiet > version.txt")
    FileUtils.rm_rf("./.git")
  end
end

require 'rake/testtask'

Rake::TestTask.new do |test|
  ENV["COVERAGE_MINIMUM"] = "true"
  test.test_files = Dir.glob('test/**/*_test.rb')
end

namespace :perf do
  desc "Validate basic workbook generation performance"
  task :validate do
    env = {
      "COVERAGE" => "false",
      "PERFORMANCE_TESTS" => "true"
    }
    command = ["ruby", "-Itest", "test/performance_test.rb"]
    abort "Performance validation failed" unless system(env, *command)
  end
end

#task :default => :test

desc "Run all examples"
task :examples do
  Dir.glob('examples/**/*.rb').each do |file|
    require './' + file.sub(/\.rb$/, '')
  end
end

desc "Compile libxlsxwriter shared library"
task :compile do
  %x{
    cd ext/fast_excel
    ruby ./extconf.rb
    make
  }
end
