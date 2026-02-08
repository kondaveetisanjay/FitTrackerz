defmodule Fitconnex.Gym.Geo do
  @moduledoc """
  Geospatial utilities for gym distance calculations using the Haversine formula.
  """

  @earth_radius_km 6371.0

  @doc """
  Calculate the Haversine distance between two lat/lng points in kilometers.
  Returns nil if any coordinate is nil.
  """
  def haversine_distance(lat1, lng1, lat2, lng2) do
    with f_lat1 when is_float(f_lat1) <- to_float(lat1),
         f_lng1 when is_float(f_lng1) <- to_float(lng1),
         f_lat2 when is_float(f_lat2) <- to_float(lat2),
         f_lng2 when is_float(f_lng2) <- to_float(lng2) do
      dlat = deg_to_rad(f_lat2 - f_lat1)
      dlng = deg_to_rad(f_lng2 - f_lng1)

      a =
        :math.sin(dlat / 2) * :math.sin(dlat / 2) +
          :math.cos(deg_to_rad(f_lat1)) * :math.cos(deg_to_rad(f_lat2)) *
            :math.sin(dlng / 2) * :math.sin(dlng / 2)

      c = 2 * :math.atan2(:math.sqrt(a), :math.sqrt(1 - a))
      @earth_radius_km * c
    else
      _ -> nil
    end
  end

  @doc """
  Given a list of gym entries (maps with a :gym key whose value has loaded :branches),
  compute the minimum distance from user coordinates to any branch of each gym.
  Returns the list sorted by nearest first. Each element is `{entry, distance_km}`.
  """
  def sort_by_nearest(gym_entries, user_lat, user_lng) do
    case {to_float(user_lat), to_float(user_lng)} do
      {lat, lng} when is_float(lat) and is_float(lng) ->
        gym_entries
        |> Enum.map(fn entry ->
          min_distance =
            entry.gym.branches
            |> Enum.map(fn branch ->
              haversine_distance(lat, lng, to_float(branch.latitude), to_float(branch.longitude))
            end)
            |> Enum.reject(&is_nil/1)
            |> case do
              [] -> nil
              distances -> Enum.min(distances)
            end

          {entry, min_distance}
        end)
        |> Enum.sort_by(fn {_entry, distance} -> distance || 99999 end)

      _ ->
        Enum.map(gym_entries, fn entry -> {entry, nil} end)
    end
  end

  defp to_float(nil), do: nil
  defp to_float(v) when is_float(v), do: v
  defp to_float(v) when is_integer(v), do: v * 1.0

  defp to_float(v) when is_binary(v) do
    case Float.parse(v) do
      {f, _} -> f
      :error -> nil
    end
  end

  defp to_float(%Decimal{} = d), do: Decimal.to_float(d)
  defp to_float(_), do: nil

  defp deg_to_rad(deg), do: deg * :math.pi() / 180.0
end
