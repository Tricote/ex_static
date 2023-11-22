defmodule ExStaticWeb.ErrorJSONTest do
  use ExStaticWeb.ConnCase, async: true

  test "renders 404" do
    assert ExStaticWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert ExStaticWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
