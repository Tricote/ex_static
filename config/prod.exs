import Config

# Note we also include the path to a cache manifest
# containing the digested version of static files. This
# manifest is generated by the `mix assets.deploy` task,
# which you should run after static files are built and
# before starting your production server.
config :ex_static, ExStaticWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  cache_manifest_skip_vsn: true

# Do not print debug messages in production
# config :logger, level: :info

# Do not print debug messages in production
config :logger,
  backends: [{LoggerFileBackend, :error_log}]

config :logger, :error_log,
  path: "logs/error.log",
  level: :error,
  format: "[$level] $message\n"

# Runtime production configuration, including reading
# of environment variables, is done on config/runtime.exs.
