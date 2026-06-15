module FastExcel
  class WorksheetRowWriter
    def initialize(worksheet, types:, formats: nil)
      @worksheet = worksheet
      @writers = types.each_with_index.map do |type, cell_number|
        build_writer(type, cell_number, format_for(formats, cell_number))
      end
    end

    def write_row(row_number, values)
      worksheet.__send__(:validate_writable_row!, row_number)

      writers.each_with_index do |writer, index|
        writer.call(row_number, values[index])
      end

      worksheet.track_written_row(row_number)
    end

    def write_rows(row_number, rows)
      rows.each_with_index do |values, index|
        write_row(row_number + index, values)
      end
    end

    def append_row(values)
      write_row(worksheet.last_row_number + 1, values)
    end

    def append_rows(rows)
      write_rows(worksheet.last_row_number + 1, rows)
    end

    private

    attr_reader :worksheet, :writers

    def build_writer(type, cell_number, format)
      case type
      when :string
        ->(row_number, value) { worksheet.write_string(row_number, cell_number, value.to_s, format) }
      when :number
        ->(row_number, value) { worksheet.write_number(row_number, cell_number, value, format) }
      when :time
        ->(row_number, value) { worksheet.write_number(row_number, cell_number, FastExcel.date_num(value), format) }
      when :date
        ->(row_number, value) { worksheet.write_datetime(row_number, cell_number, FastExcel.lxw_datetime(value.to_datetime), format) }
      when :datetime
        ->(row_number, value) { worksheet.write_number(row_number, cell_number, FastExcel.date_num(value), format) }
      when :url
        ->(row_number, value) { worksheet.write_url(row_number, cell_number, value.url, format) }
      when :formula
        ->(row_number, value) { worksheet.write_formula(row_number, cell_number, value.fml, format) }
      when :boolean
        ->(row_number, value) { worksheet.write_boolean(row_number, cell_number, value ? 1 : 0, format) }
      else
        raise ArgumentError, "Unknown row writer type #{type.inspect}"
      end
    end

    def format_for(formats, cell_number)
      return nil unless formats

      formats.is_a?(Array) ? formats[cell_number] : formats
    end
  end

  private_constant :WorksheetRowWriter
end
