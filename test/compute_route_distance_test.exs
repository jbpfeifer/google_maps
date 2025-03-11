defmodule ComputeRouteDistanceTest do
  use ExUnit.Case, async: true

  setup do
    bypass = Bypass.open()
    api_url = "http://localhost:#{bypass.port}"
    original_url = Application.get_env(:google_maps, :api_url)

    Application.put_env(:google_maps, :api_url, api_url)

    on_exit(fn ->
      Application.put_env(:google_maps, :api_url, original_url)
    end)

    {:ok, bypass: bypass}
  end

  describe "compute_route_distance/3" do
    test "returns distance for coordinate inputs", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/directions/v2:computeRoutes", fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        assert conn.query_params["key"] != nil

        # Verify correct request body format
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)

        assert request["origin"]["location"]["latLng"] == %{
                 "latitude" => 48.8566,
                 "longitude" => 2.3522
               }

        assert request["destination"]["location"]["latLng"] == %{
                 "latitude" => 51.5074,
                 "longitude" => -0.1278
               }

        response = %{
          "routes" => [
            %{
              "distanceMeters" => 342_978
            }
          ]
        }

        Plug.Conn.resp(conn, 200, Jason.encode!(response))
      end)

      assert {:ok, result} =
               GoogleMaps.compute_route_distance({48.8566, 2.3522}, {51.5074, -0.1278})

      assert [route] = result["routes"]
      assert route["distanceMeters"] == 342_978
    end

    test "returns distance for string address inputs", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/directions/v2:computeRoutes", fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)
        assert conn.query_params["key"] != nil

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)

        assert request["origin"]["address"] == "Paris, France"
        assert request["destination"]["address"] == "London, UK"

        response = %{
          "routes" => [
            %{
              "distanceMeters" => 342_978
            }
          ]
        }

        Plug.Conn.resp(conn, 200, Jason.encode!(response))
      end)

      assert {:ok, result} = GoogleMaps.compute_route_distance("Paris, France", "London, UK")
      assert [route] = result["routes"]
      assert route["distanceMeters"] == 342_978
    end

    test "handles travel mode option", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/directions/v2:computeRoutes", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        request = Jason.decode!(body)

        assert request["travelMode"] == "WALK"

        response = %{
          "routes" => [
            %{
              "distanceMeters" => 342_978
            }
          ]
        }

        Plug.Conn.resp(conn, 200, Jason.encode!(response))
      end)

      assert {:ok, result} =
               GoogleMaps.compute_route_distance(
                 "Paris, France",
                 "London, UK",
                 mode: "walking"
               )

      assert [route] = result["routes"]
      assert route["distanceMeters"] == 342_978
    end

    test "handles API error responses", %{bypass: bypass} do
      Bypass.expect_once(bypass, "POST", "/directions/v2:computeRoutes", fn conn ->
        response = %{
          "error" => %{
            "code" => 400,
            "message" => "Invalid request",
            "status" => "INVALID_ARGUMENT"
          }
        }

        Plug.Conn.resp(conn, 400, Jason.encode!(response))
      end)

      assert {:error, "INVALID_ARGUMENT", "Invalid request"} =
               GoogleMaps.compute_route_distance("Invalid Address", "Also Invalid")
    end
  end
end
