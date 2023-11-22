import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :ex_static, ExStaticWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "HwSjy2e1mc1yDS3ir82xo9m79xatKa04l7bUtUdtFsTpbN7FGSaO/wDKJ5+qVEoE",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
