require_relative "test_helper"

class GemspecTest < Minitest::Test
  def setup
    @spec = Gem::Specification.load(File.expand_path("../uber_fast_excel.gemspec", __dir__))
  end

  def test_promoted_gem_metadata
    assert_equal "uber_fast_excel", @spec.name
    assert_equal "Ultra Fast Excel Writer for Ruby", @spec.summary
    assert_equal "https://github.com/willfish/fast_excel", @spec.homepage
    assert_equal ["William Fish"], @spec.authors
    assert_equal "MIT", @spec.license
    assert_operator Gem::Version.new(@spec.required_ruby_version.requirements.first.last.version), :>=, Gem::Version.new("2.7")
  end

  def test_gem_files_include_compatibility_require_path
    assert_includes @spec.files, "lib/fast_excel.rb"
    assert_includes @spec.files, "lib/uber_fast_excel.rb"
    assert_includes @spec.files, "lib/fast_excel/binding.rb"
    refute_includes @spec.files, "fast_excel-0.5.0.gem"
  end

  def test_default_require_path_loads_fast_excel_api
    require "uber_fast_excel"

    assert defined?(FastExcel)
    assert_respond_to FastExcel, :open
  end
end
