import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :fitconnex, Fitconnex.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "fitconnex_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :fitconnex, FitconnexWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "JN/wkjAi3sNnMfF3fwhWqtpivOkXbRJ1aHF6rhLgGUo6NJ7Y2i0nGTh3abIx22wr",
  server: false

# In test we don't send emails
config :fitconnex, Fitconnex.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Token signing secret for AshAuthentication
config :fitconnex,
       :token_signing_secret,
       "test-only-token-signing-secret-at-least-32-chars-long!!"

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
