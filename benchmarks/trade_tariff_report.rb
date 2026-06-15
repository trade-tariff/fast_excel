require "json"
require "etc"
require "rbconfig"
require "stringio"
require "tmpdir"
require "zip"

require_relative "../lib/fast_excel"

module FastExcel
  module Benchmarks
    class TradeTariffReport
      HEADERS = [
        "Commodity code",
        "Description",
        "Status",
        "Duty rate",
        "Effective at",
        "Measure count",
        "Change formula",
        "Reference URL",
        "Notes"
      ].freeze

      STATUSES = ["Active", "Expired", "Suspended", "Declarable"].freeze

      Result = Struct.new(
        :rows,
        :seconds,
        :bytes,
        :zip_compressed_bytes,
        :zip_uncompressed_bytes,
        :allocated_objects,
        :heap_live_slots_delta,
        :rss_bytes_delta,
        :platform,
        keyword_init: true
      ) do
        def compression_ratio
          return nil if zip_uncompressed_bytes.to_i == 0

          zip_compressed_bytes.to_f / zip_uncompressed_bytes
        end

        def to_h
          {
            rows: rows,
            seconds: seconds,
            bytes: bytes,
            zip_compressed_bytes: zip_compressed_bytes,
            zip_uncompressed_bytes: zip_uncompressed_bytes,
            compression_ratio: compression_ratio,
            allocated_objects: allocated_objects,
            heap_live_slots_delta: heap_live_slots_delta,
            rss_bytes_delta: rss_bytes_delta,
            platform: platform
          }
        end
      end

      def initialize(rows: 2_000, constant_memory: true)
        @rows = rows
        @constant_memory = constant_memory
      end

      def run
        GC.start
        before_gc = GC.stat
        before_rss = rss_bytes
        started_at = monotonic_time

        content = build_workbook

        finished_at = monotonic_time
        after_gc = GC.stat
        after_rss = rss_bytes
        zip = zip_stats(content)

        Result.new(
          rows: rows,
          seconds: finished_at - started_at,
          bytes: content.bytesize,
          zip_compressed_bytes: zip.fetch(:compressed_bytes),
          zip_uncompressed_bytes: zip.fetch(:uncompressed_bytes),
          allocated_objects: after_gc.fetch(:total_allocated_objects) - before_gc.fetch(:total_allocated_objects),
          heap_live_slots_delta: after_gc.fetch(:heap_live_slots) - before_gc.fetch(:heap_live_slots),
          rss_bytes_delta: rss_delta(before_rss, after_rss),
          platform: platform_metadata
        )
      end

      private

      attr_reader :rows, :constant_memory

      def build_workbook
        workbook = FastExcel.open(constant_memory: constant_memory)
        worksheet = workbook.add_worksheet("Measures")

        header = workbook.add_format(bold: true, bg_color: :light_blue, border: :border_thin)
        money = workbook.number_format("#,##0.00")
        date = workbook.number_format("yyyy-mm-dd")
        active = workbook.add_format(font_color: :green)
        inactive = workbook.add_format(font_color: :dark_red)
        bold = workbook.bold_format

        worksheet.write_row(0, HEADERS, header)

        rows.times do |index|
          status = STATUSES[index % STATUSES.length]
          status_format = status == "Active" ? active : inactive

          worksheet.write_row(index + 1, [
            format("%010d", 1_000_000_000 + index),
            description_for(index),
            status,
            (index % 17) * 1.25,
            Time.utc(2026, 1, 1) + (index * 86_400),
            index % 31,
            FastExcel::Formula.new("D#{index + 2}*F#{index + 2}"),
            FastExcel::URL.new("https://www.trade-tariff.service.gov.uk/commodities/#{format("%010d", 1_000_000_000 + index)}"),
            notes_for(index, bold)
          ], [nil, nil, status_format, money, date, nil, nil, nil, nil])
        end

        worksheet.enable_filters!(end_col: HEADERS.length - 1)
        workbook.read_string
      end

      def description_for(index)
        base = "Prepared food product #{index} with seasonal classification"
        index % 10 == 0 ? "#{base} & import controls <review>" : base
      end

      def notes_for(index, bold)
        return "Routine measure" unless index % 25 == 0

        FastExcel::RichString.new([
          { text: "Review ", format: bold },
          { text: "rules of origin and duty suspension" }
        ])
      end

      def zip_stats(content)
        compressed = 0
        uncompressed = 0

        Zip::File.open_buffer(StringIO.new(content)) do |zip|
          zip.each do |entry|
            compressed += entry.compressed_size
            uncompressed += entry.size
          end
        end

        { compressed_bytes: compressed, uncompressed_bytes: uncompressed }
      end

      def platform_metadata
        {
          ruby_version: RUBY_VERSION,
          ruby_platform: RUBY_PLATFORM,
          host_cpu: RbConfig::CONFIG["host_cpu"],
          host_os: RbConfig::CONFIG["host_os"],
          target: RbConfig::CONFIG["target"],
          yjit: defined?(RubyVM::YJIT) ? RubyVM::YJIT.enabled? : false,
          libxlsxwriter_candidates: native_library_candidates
        }
      end

      def native_library_candidates
        suffix = Libxlsxwriter::LIB_FILENAME
        [
          Gem.loaded_specs["uber_fast_excel"]&.extension_dir,
          Gem.loaded_specs["fast_excel"]&.extension_dir,
          File.expand_path("../lib", __dir__)
        ].compact.map { |directory| File.join(directory, suffix) }
      end

      def rss_bytes
        return nil unless File.exist?("/proc/self/statm")

        pages = File.read("/proc/self/statm").split.fetch(1).to_i
        pages * Etc.sysconf(Etc::SC_PAGE_SIZE)
      rescue StandardError
        nil
      end

      def rss_delta(before_rss, after_rss)
        return nil if before_rss.nil? || after_rss.nil?

        after_rss - before_rss
      end

      def monotonic_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end

if $PROGRAM_NAME == __FILE__
  rows = Integer(ENV.fetch("TRADE_TARIFF_PERFORMANCE_ROWS", "2000"))
  result = FastExcel::Benchmarks::TradeTariffReport.new(rows: rows).run
  puts JSON.pretty_generate(result.to_h)
end
