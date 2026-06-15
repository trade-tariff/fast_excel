require_relative "test_helper"

describe "FastExcel.print_ffi_obj" do
  it "returns a printable representation without writing to stdout" do
    options = Libxlsxwriter::WorkbookOptions.new
    options[:constant_memory] = 1

    output = FastExcel.print_ffi_obj(options, do_print: false)

    assert_includes(output, "Libxlsxwriter::WorkbookOptions")
    assert_includes(output, "* constant_memory: 1")
  end

  it "prints when requested" do
    options = Libxlsxwriter::WorkbookOptions.new
    options[:constant_memory] = 1

    printed = capture_io do
      FastExcel.print_ffi_obj(options)
    end.first

    assert_includes(printed, "Libxlsxwriter::WorkbookOptions")
  end
end
