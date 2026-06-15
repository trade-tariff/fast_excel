require "pathname"
require_relative "test_helper"

describe "FastExcel.open" do
  it "accepts pathname filenames" do
    path = Pathname.new("pathname_workbook.xlsx")

    workbook = FastExcel.open(path)
    workbook.add_worksheet.append_row(["ok"])
    workbook.close

    assert_equal [["ok"]], parse_xlsx_as_matrix(path.to_s)
  end

  it "raises when default_format is not a hash" do
    error = assert_raises(RuntimeError) do
      FastExcel.open(default_format: "Arial")
    end

    assert_equal "default_format argument must be a hash", error.message
  end

  it "reports constant memory mode" do
    constant_memory_workbook = FastExcel.open(constant_memory: true)
    regular_workbook = FastExcel.open(constant_memory: false)

    assert constant_memory_workbook.constant_memory?
    refute regular_workbook.constant_memory?

    constant_memory_workbook.read_string
    regular_workbook.read_string
  end
end
