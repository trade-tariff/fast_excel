require_relative "test_helper"

describe "numeric serialization" do
  it "round trips representative numeric values" do
    values = [
      0,
      1,
      -1,
      12.5,
      0.123456789012345,
      12_345_678.9012345,
      FastExcel.date_num(Time.utc(2026, 6, 15, 10, 20, 30))
    ]

    workbook = FastExcel.open(constant_memory: true)
    worksheet = workbook.add_worksheet
    worksheet.append_row(values)
    workbook.close

    row = parse_xlsx_as_matrix(workbook.filename).first

    values.each_with_index do |expected, index|
      assert_in_delta(expected, row[index], 0.0000000001)
    end
  end
end
