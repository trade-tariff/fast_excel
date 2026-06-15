require "benchmark"
require "json"
require_relative "test_helper"
require_relative "../benchmarks/trade_tariff_report"

describe "FastExcel performance" do
  it "writes a large constant-memory workbook within the regression budget" do
    skip "set PERFORMANCE_TESTS=true to run performance validations" unless ENV["PERFORMANCE_TESTS"] == "true"

    rows = Integer(ENV.fetch("PERFORMANCE_ROWS", "20000"))
    max_seconds = Float(ENV.fetch("PERFORMANCE_MAX_SECONDS", "10"))

    elapsed = Benchmark.realtime do
      workbook = FastExcel.open(constant_memory: true)
      worksheet = workbook.add_worksheet("Performance")
      worksheet.append_row(["code", "status", "value"])

      rows.times do |index|
        worksheet.append_row([
          format("%010d", index),
          index.even? ? "Active" : "Suspended",
          index
        ])
      end

      content = workbook.read_string
      assert_operator content.bytesize, :>, 1000
    end

    assert_operator elapsed, :<, max_seconds, "expected #{rows} rows in under #{max_seconds}s, got #{elapsed.round(3)}s"
  end

  it "writes a Trade Tariff-shaped constant-memory workbook within the regression budget" do
    skip "set PERFORMANCE_TESTS=true to run performance validations" unless ENV["PERFORMANCE_TESTS"] == "true"

    rows = Integer(ENV.fetch("TRADE_TARIFF_PERFORMANCE_ROWS", "2000"))
    max_seconds = Float(ENV.fetch("TRADE_TARIFF_PERFORMANCE_MAX_SECONDS", "10"))

    result = FastExcel::Benchmarks::TradeTariffReport.new(rows: rows).run

    warn "\nTrade Tariff benchmark: #{JSON.pretty_generate(result.to_h)}" if ENV["VERBOSE_PERFORMANCE"] == "true"

    assert_equal rows, result.rows
    assert_operator result.bytes, :>, 10_000
    assert_operator result.zip_compressed_bytes, :>, 0
    assert_operator result.zip_uncompressed_bytes, :>, result.zip_compressed_bytes
    assert_operator result.seconds, :<, max_seconds, "expected #{rows} Trade Tariff-shaped rows in under #{max_seconds}s, got #{result.seconds.round(3)}s"
  end
end
