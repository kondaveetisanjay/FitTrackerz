defmodule FitTrackerz.Billing.PricingHelpers do
  @moduledoc """
  Helper functions for pricing calculations and display formatting.
  """

  @duration_months %{
    day_pass: nil,
    monthly: 1,
    quarterly: 3,
    half_yearly: 6,
    annual: 12,
    two_year: 24
  }

  @duration_labels %{
    day_pass: "Day Pass",
    monthly: "Monthly",
    quarterly: "3 Months",
    half_yearly: "6 Months",
    annual: "Yearly",
    two_year: "2 Years"
  }

  def duration_months(duration), do: Map.get(@duration_months, duration)

  def duration_label(duration), do: Map.get(@duration_labels, duration, to_string(duration))

  def format_price(price_in_paise) when is_integer(price_in_paise) do
    rupees = div(price_in_paise, 100)

    rupees
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end

  def format_price(_), do: "0"

  def per_month_price(price_in_paise, duration) do
    case duration_months(duration) do
      nil -> nil
      months -> div(price_in_paise, months)
    end
  end

  def savings_percentage(_price_in_paise, :monthly, _monthly_price), do: 0

  def savings_percentage(price_in_paise, duration, monthly_price) do
    case duration_months(duration) do
      nil ->
        0

      months ->
        full_monthly_cost = monthly_price * months

        if full_monthly_cost > 0 do
          round((full_monthly_cost - price_in_paise) / full_monthly_cost * 100)
        else
          0
        end
    end
  end
end
