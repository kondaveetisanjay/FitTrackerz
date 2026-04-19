defmodule FitTrackerzWeb.AshErrorHelpers do
  @moduledoc """
  Translates Ash errors into user-friendly flash messages.
  """

  def user_friendly_message(%Ash.Error.Invalid{errors: errors}) do
    errors
    |> Enum.map(&format_error/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> case do
      [] -> "Validation failed. Please check your input."
      messages -> Enum.join(messages, ". ")
    end
  end

  def user_friendly_message(%Ash.Error.Forbidden{}) do
    "You don't have permission to perform this action."
  end

  def user_friendly_message(%Ash.Error.Framework{}) do
    "An internal error occurred. Please try again."
  end

  def user_friendly_message(_), do: "Something went wrong. Please try again."

  defp format_error(%Ash.Error.Changes.InvalidAttribute{field: field, message: message}) do
    cond do
      is_nil(message) or message == "" ->
        "#{humanize(field)} is invalid"

      # If message is already a full sentence (starts with capital letter), show as-is
      String.match?(message, ~r/^[A-Z]/) ->
        message

      true ->
        "#{humanize(field)} #{message}"
    end
  end

  defp format_error(%Ash.Error.Changes.InvalidChanges{message: message}) when is_binary(message) do
    message
  end

  defp format_error(%Ash.Error.Changes.Required{field: field}) do
    "#{humanize(field)} is required"
  end

  defp format_error(%Ash.Error.Query.NotFound{}) do
    "Record not found"
  end

  defp format_error(%Ash.Error.Invalid.NoSuchAction{}) do
    "Invalid action requested"
  end

  defp format_error(_), do: nil

  defp humanize(field) when is_atom(field), do: field |> Atom.to_string() |> humanize()

  defp humanize(field) when is_binary(field) do
    field
    |> String.replace("_", " ")
    |> String.capitalize()
  end
end
