defmodule SearchTantivy.ValueTest do
  use ExUnit.Case, async: true

  alias SearchTantivy.Value

  describe "to_string_value/1" do
    test "binaries pass through unchanged" do
      assert {:ok, "hello"} = Value.to_string_value("hello")
    end

    test "integers" do
      assert {:ok, "42"} = Value.to_string_value(42)
      assert {:ok, "-7"} = Value.to_string_value(-7)
    end

    test "floats" do
      assert {:ok, "3.14"} = Value.to_string_value(3.14)
    end

    test "booleans" do
      assert {:ok, "true"} = Value.to_string_value(true)
      assert {:ok, "false"} = Value.to_string_value(false)
    end

    test "atoms" do
      assert {:ok, "ok"} = Value.to_string_value(:ok)
    end

    test "nil renders as empty string" do
      assert {:ok, ""} = Value.to_string_value(nil)
    end

    test "DateTime is ISO8601" do
      dt = ~U[2024-01-15 10:30:00Z]
      assert {:ok, "2024-01-15T10:30:00Z"} = Value.to_string_value(dt)
    end

    test "NaiveDateTime is ISO8601" do
      dt = ~N[2024-01-15 10:30:00]
      assert {:ok, "2024-01-15T10:30:00"} = Value.to_string_value(dt)
    end

    test "unsupported types return {:error, :unsupported_type}" do
      assert {:error, :unsupported_type} = Value.to_string_value({:tuple, :is, :unsupported})
      assert {:error, :unsupported_type} = Value.to_string_value([1, 2, 3])
      assert {:error, :unsupported_type} = Value.to_string_value(%{not: "supported"})
      assert {:error, :unsupported_type} = Value.to_string_value(self())
    end
  end

  describe "to_string_value!/1" do
    test "returns the string for supported types" do
      assert "hello" = Value.to_string_value!("hello")
      assert "42" = Value.to_string_value!(42)
      assert "ok" = Value.to_string_value!(:ok)
    end

    test "raises ArgumentError for unsupported types" do
      assert_raise ArgumentError, ~r/cannot convert/, fn ->
        Value.to_string_value!({:tuple, :unsupported})
      end
    end
  end
end
