defmodule Fitconnex.Repo do
  use AshPostgres.Repo,
    otp_app: :fitconnex

  def installed_extensions do
    ["uuid-ossp", "citext", "ash-functions", "postgis"]
  end

  def min_pg_version do
    %Version{major: 16, minor: 0, patch: 0}
  end
end
