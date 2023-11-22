%{
  title: "Replace default Tailwind by Bootstrap 5 in Phoenix",
  author: "Tricote",
  tags: ~w(Phoenix Bootstrap)
}
---

In `mix.exs`, removes the `tailwind` library and add the `dart_saas` library:

```elixir
defp deps do
  [
    # ...
    # {:tailwind, "~> 0.2.0", runtime: Mix.env() == :dev},
    {:dart_sass, "~> 0.6", runtime: Mix.env() == :dev},
    # ...
  }
end
```

Add the bootstrap package

```sh
cd assets
npm install bootstrap
```

In `mix.exs`, replace tailwind build command with the npm and saas command:

```elixir
defp aliases do
  [
    setup: ["deps.get"],
    "assets.deploy": [
      # "tailwind default --minify",
      "cmd npm --prefix assets install", # <- here
      "sass default --no-source-map --style=compressed", # <- here
      "esbuild default --minify",
      "phx.digest"
    ]
  ]
end
```

Rename `assets/css/app.css` to `assets/css/app.scss`

Delete `assets/tailwind.config.js`

In `config/config.exs`, replace tailwind config with dart_saas config:

```elixir
# Configure tailwind (the version is required)
# config :tailwind,
#   version: "3.3.2",
#   default: [
#     args: ~w(
#       --config=tailwind.config.js
#       --input=css/app.css
#       --output=../priv/static/assets/app.css
#     ),
#     cd: Path.expand("../assets", __DIR__)
#   ]

#  Configure dart_sass for SCSS building
config :dart_sass,
  version: "1.61.0",
  default: [
    args: ~w(css/app.scss ../priv/static/assets/app.css),
    cd: Path.expand("../assets", __DIR__)
  ]
```

in `config/dev.exs`, configure sass watcher

```elixir
config :ex_static, ExStaticWeb.Endpoint,
  # Binding to loopback ipv4 address prevents access from other machines.
  # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "vQoLVWkQsOzoLp3vUT3chIOZVlgNJg3oLOZJr/HUE1iyjV8ZGTYD4D5PM48FxHOj",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]},
    # tailwind: {Tailwind, :install_and_run, [:default, ~w(--watch)]}
    sass:
      {DartSass, :install_and_run,
       [:default, ~w(--embed-source-map --source-map-urls=absolute --watch)]} # <- here
  ]
```

Import bootstrap into your `assets/app.scss` file. You may also override Bootstrap variables like this:

```json
// Custom Variables (will override boostrap variables)
$primary: #326f84;
$secondary: #FF7F00;

// Import Bootstrap
@import '../node_modules/bootstrap/scss/bootstrap';

// Custom CSS
// ...
```