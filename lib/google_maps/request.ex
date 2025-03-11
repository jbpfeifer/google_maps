defmodule GoogleMaps.Request do
  @moduledoc false

  @doc """
  GET an endpoint with param keyword list
  """
  @spec get(String.t(), keyword()) :: GoogleMaps.Response.t()
  def get(endpoint, params) do
    {secure, params} = Keyword.pop(params, :secure)
    {output, params} = Keyword.pop(params, :output, "json")
    {key, params} = Keyword.pop(params, :key, api_key())
    {headers, params} = Keyword.pop(params, :headers, [])
    {options, params} = Keyword.pop(params, :options, [])

    unless is_nil(secure) do
      IO.puts("`secure` param is deprecated since Google requires request over SSL with API key.")
    end

    query =
      params
      |> Keyword.put(:key, key)
      |> Enum.map(&transform_param/1)
      |> URI.encode_query()

    case endpoint do
      "compute_route_distance" ->
        query = "key=#{key}"
        url = "https://routes.googleapis.com/directions/v2:computeRoutes"

        headers = [
          {"Content-Type", "application/json"},
          {"X-Goog-FieldMask", "routes.distanceMeters"}
          | headers
        ]

        body =
          %{
            origin: format_location(Keyword.get(params, :origin)),
            destination: format_location(Keyword.get(params, :destination)),
            travelMode: get_travel_mode(Keyword.get(params, :mode, "driving")),
            languageCode: Keyword.get(params, :language, "en-US"),
            units: "METRIC"
          }
          |> Jason.encode!()

        requester().post("#{url}?#{query}", body, headers, options)

      _ ->
        url = Path.join("https://maps.googleapis.com/maps/api/#{endpoint}", output)

        requester().get("#{url}?#{query}", headers, options)
        |> format_headers()
    end
  end

  # Helpers

  defp api_key do
    Application.get_env(:google_maps, :api_key) ||
      System.get_env("GOOGLE_MAPS_API_KEY")
  end

  defp requester do
    Application.get_env(:google_maps, :requester)
  end

  defp transform_param({type, {lat, lng}})
       when type in [:origin, :destination] and
              is_number(lat) and
              is_number(lng) do
    {type, "#{lat},#{lng}"}
  end

  defp transform_param({type, {:place_id, place_id}})
       when type in [:origin, :destination] do
    {type, "place_id:#{place_id}"}
  end

  defp transform_param({:waypoints, "enc:" <> enc}) do
    {:waypoints, "enc:" <> enc}
  end

  defp transform_param({:waypoints, waypoints})
       when is_list(waypoints) do
    transform_param({:waypoints, Enum.join(waypoints, "|")})
  end

  defp transform_param({:waypoints, waypoints}) do
    # @TODO: Encode the waypoints into encoded polyline.
    {:waypoints, "optimize:true|#{waypoints}"}
  end

  defp transform_param(param), do: param

  defp format_headers({:ok, %{headers: headers} = response}) do
    {:ok, %{response | headers: Map.new(headers)}}
  end

  defp format_headers(error), do: error

  # New helper functions
  defp format_location({lat, lng}) when is_number(lat) and is_number(lng) do
    %{
      "location" => %{
        "latLng" => %{
          "latitude" => lat,
          "longitude" => lng
        }
      }
    }
  end

  defp format_location(address) when is_binary(address) do
    %{
      "address" => address
    }
  end

  defp get_travel_mode(mode) do
    case String.upcase(mode) do
      "DRIVING" -> "DRIVE"
      "WALKING" -> "WALK"
      "BICYCLING" -> "BICYCLE"
      "TRANSIT" -> "TRANSIT"
      _ -> "DRIVE"
    end
  end
end
