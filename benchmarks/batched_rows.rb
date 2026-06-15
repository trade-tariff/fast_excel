require "json"
require "rbconfig"

require_relative "../lib/fast_excel"

module FastExcel
  module Benchmarks
    class BatchedRows
      HEADERS = ["Code", "Description", "Rate", "Effective at", "URL"].freeze

      Result = Struct.new(:rows, :columns, :methods, :platform, keyword_init: true) do
        def to_h
          {
            rows: rows,
            columns: columns,
            methods: methods,
            platform: platform
          }
        end
      end

      def initialize(rows: 2_000, constant_memory: true)
        @rows = rows
        @constant_memory = constant_memory
        @data = build_data
      end

      def run
        Result.new(
          rows: rows,
          columns: HEADERS.length,
          methods: {
            write_value: measure { |worksheet| write_with_values(worksheet) },
            write_row: measure { |worksheet| write_with_rows(worksheet) },
            append_row: measure { |worksheet| write_with_append_rows(worksheet) },
            append_rows: measure { |worksheet| worksheet.append_rows(data) },
            compiled_row_writer: measure { |worksheet| write_with_compiled_row_writer(worksheet) }
          },
          platform: platform_metadata
        )
      end

      private

      attr_reader :rows, :constant_memory, :data

      def measure
        workbook = FastExcel.open(constant_memory: constant_memory)
        worksheet = workbook.add_worksheet("Rows")
        worksheet.write_row(0, HEADERS)

        started_at = monotonic_time
        yield worksheet
        content = workbook.read_string
        finished_at = monotonic_time

        {
          seconds: finished_at - started_at,
          bytes: content.bytesize
        }
      end

      def write_with_values(worksheet)
        data.each_with_index do |row, row_number|
          row.each_with_index do |value, cell_number|
            worksheet.write_value(row_number + 1, cell_number, value)
          end
        end
      end

      def write_with_rows(worksheet)
        data.each_with_index do |row, row_number|
          worksheet.write_row(row_number + 1, row)
        end
      end

      def write_with_append_rows(worksheet)
        data.each do |row|
          worksheet.append_row(row)
        end
      end

      def write_with_compiled_row_writer(worksheet)
        row_writer = worksheet.compile_row_writer(types: [:string, :string, :number, :time, :url])
        row_writer.append_rows(data)
      end

      def build_data
        Array.new(rows) do |index|
          [
            format("%010d", 1_000_000_000 + index),
            "Prepared food product #{index}",
            (index % 17) * 1.25,
            Time.utc(2026, 1, 1) + (index * 86_400),
            FastExcel::URL.new("https://www.trade-tariff.service.gov.uk/commodities/#{format("%010d", 1_000_000_000 + index)}")
          ]
        end
      end

      def platform_metadata
        {
          ruby_version: RUBY_VERSION,
          ruby_platform: RUBY_PLATFORM,
          host_cpu: RbConfig::CONFIG["host_cpu"],
          host_os: RbConfig::CONFIG["host_os"]
        }
      end

      def monotonic_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  rows = Integer(ENV.fetch("BATCHED_ROWS", "2000"))
  result = FastExcel::Benchmarks::BatchedRows.new(rows: rows).run
  puts JSON.pretty_generate(result.to_h)
end
