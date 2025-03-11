defmodule GoogleMaps.Response do
  @moduledoc false

  @type t :: {:ok, map()} | {:error, any()} | {:error, String.t(), String.t()}

  @type status :: String.t()

  @type error :: HTTPoison.Error.t() | status()

  @spec wrap(tuple()) :: t()
  def wrap({:ok, %{status_code: 200, body: body} = response}) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, %{"error" => error}} ->
        {:error, error["status"], error["message"]}

      {:ok, decoded} when is_map(decoded) ->
        # Handle both classic Maps API and new Routes API responses
        case decoded do
          %{"status" => "OK"} ->
            {:ok, decoded}

          %{"routes" => _} ->
            # New Routes API response doesn't include a status field
            {:ok, decoded}

          %{"status" => status, "error_message" => message} ->
            {:error, status, message}

          %{"status" => status} ->
            {:error, status}
        end

      _ ->
        {:ok, response}
    end
  end

  def wrap({:ok, response}), do: {:ok, response}
  def wrap({:error, error}), do: {:error, error}
end
