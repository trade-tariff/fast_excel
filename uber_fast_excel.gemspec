Gem::Specification.new do |s|
  s.name        = "uber_fast_excel"
  s.version     = "0.6.0"
  s.authors     = ["William Fish"]
  s.email       = ["will@willfish.org"]
  s.homepage    = "https://github.com/willfish/fast_excel"
  s.summary     = "Ultra Fast Excel Writer for Ruby"
  s.description = "Maintained Ruby FFI bindings for libxlsxwriter with convenience APIs for generating XLSX workbooks."
  s.license     = "MIT"
  s.required_ruby_version = ">= 2.7"

  s.metadata = {
    "bug_tracker_uri" => "https://github.com/willfish/fast_excel/issues",
    "changelog_uri" => "https://github.com/willfish/fast_excel/blob/master/CHANGELOG.md",
    "documentation_uri" => "https://www.rubydoc.info/gems/uber_fast_excel",
    "source_code_uri" => "https://github.com/willfish/fast_excel",
    "rubygems_mfa_required" => "true"
  }

  tracked_files = `git ls-files`.split("\n")
  deleted_files = `git ls-files --deleted`.split("\n")
  new_files = `git ls-files --others --exclude-standard`.split("\n")

  s.files = ((tracked_files - deleted_files) + new_files).uniq
  s.test_files = s.files.grep(%r{\Atest/.*_test\.rb\z})

  s.require_paths = ["lib"]
  s.extensions = ["extconf.rb"]

  s.add_runtime_dependency "ffi", ["> 1.17", "< 2"]
  s.add_runtime_dependency "base64", [">= 0.2", "< 2"]
end
