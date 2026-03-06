defmodule FitTrackerz.Gym.ReverseGeocode do
  @moduledoc """
  Reverse geocoding using Google Maps Geocoding API.
  Converts lat/lng coordinates to a human-readable place name.
  """

  @google_geocode_url "https://maps.googleapis.com/maps/api/geocode/json"

  @doc """
  Reverse geocode coordinates to a place name like "Bricks Skywoods, Tellapur, Hyderabad".
  Returns the place name string or a fallback coordinate string.
  """
  def reverse_geocode(lat, lng) when is_number(lat) and is_number(lng) do
    case api_key() do
      nil -> {:ok, format_coords(lat, lng)}
      key -> call_google_api(lat, lng, key)
    end
  end

  def reverse_geocode(_, _), do: {:ok, "Unknown location"}

  defp call_google_api(lat, lng, key) do
    url = "#{@google_geocode_url}?latlng=#{lat},#{lng}&key=#{key}&language=en"

    case Req.get(url) do
      {:ok, %{status: 200, body: %{"status" => "OK", "results" => results}}}
      when is_list(results) and results != [] ->
        place_name = extract_best_name(results)
        {:ok, place_name}

      {:ok, %{status: 200, body: %{"status" => status}}} ->
        {:error, "Geocoding failed: #{status}"}

      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  defp extract_best_name(results) do
    # First, check if any result is a named POI/establishment
    poi_name = find_poi_name(results)

    # Extract area components from the first result
    first = List.first(results)
    components = first["address_components"] || []

    # neighborhood = recognizable area name (e.g. "NTR Nagar", "Tellapur")
    neighborhood = find_component(components, "neighborhood")
    # sublocality_level_1 = broader area (e.g. "Osman Nagar", "Gachibowli")
    sublocality1 = find_component(components, "sublocality_level_1")
    # locality = city (e.g. "Hyderabad")
    locality = find_component(components, "locality")

    # Priority: POI name > neighborhood > sublocality1 > city
    # Skip: premise (building numbers like "6"), sublocality 2/3 (obscure villages)
    candidates = [poi_name, neighborhood, sublocality1, locality]

    parts =
      candidates
      |> Enum.reject(&is_nil/1)
      |> Enum.reject(&plus_code?/1)
      |> Enum.uniq_by(&String.downcase/1)
      |> Enum.take(3)

    case parts do
      [] -> first["formatted_address"] || "Unknown location"
      _ -> Enum.join(parts, ", ")
    end
  end

  # Scan all results for a point_of_interest or establishment name
  defp find_poi_name(results) do
    poi_types = ["point_of_interest", "establishment"]

    Enum.find_value(results, fn result ->
      types = result["types"] || []

      if Enum.any?(types, &(&1 in poi_types)) do
        # Return the name from the first address component (the POI itself)
        case result["address_components"] do
          [first_comp | _] ->
            name = first_comp["long_name"]
            # Skip if it's just a number or very short
            if name && String.length(name) > 3 && !numeric?(name) && !plus_code?(name),
              do: name

          _ ->
            nil
        end
      end
    end)
  end

  defp numeric?(str), do: Regex.match?(~r/\A[\d\s\-\/]+\z/, str)

  # Google Plus Codes look like "C8X2+WXX" or "849VCWC8+R9"
  defp plus_code?(str), do: Regex.match?(~r/\A[A-Z0-9]{4,8}\+[A-Z0-9]+\z/i, str)

  defp find_component(components, type) do
    case Enum.find(components, fn c -> type in c["types"] end) do
      nil -> nil
      comp -> comp["long_name"]
    end
  end

  defp api_key do
    Application.get_env(:fit_trackerz, :google_maps_api_key)
  end

  defp format_coords(lat, lng) do
    lat_str = :erlang.float_to_binary(lat * 1.0, decimals: 4)
    lng_str = :erlang.float_to_binary(lng * 1.0, decimals: 4)
    "#{lat_str}, #{lng_str}"
  end
end
