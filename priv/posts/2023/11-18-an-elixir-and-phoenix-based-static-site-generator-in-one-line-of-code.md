%{
  title: "An Elixir and Phoenix based static site generator in one line of code",
  author: "Tricote",
  tags: ~w(Phoenix)
}
---

If you already are an Elixir developper, you have pretty solid static site builder that comes with all the power features of Elixir and Phoenix! It's just one line of code:

```
wget -r -k -E -P public/ --no-host-directories http://localhost:4000/
```

It's actually not even Elixir code 😅. The concept is pretty simple: build the site locally with your favorite web framework, run a webserver, mirror a full copy with WGET, then upload the result to a static hosting provider. The idea is [nothing new](https://www.eddymens.com/blog/how-to-build-your-own-static-site-generator). I'm sure there are many other examples using various web frameworks. But as I needed to host a static website for a project, I wanted to give this approach a try with Phoenix.


But... why not use Jekyll of Hugo or a specialized static site buider?
--------------------------------------------------------------------

Well, simply because I like the development environment of Elixir and Phoenix. It comes with with great toolings, even for building static sites:

* Bundling/Minification/Integrity/Cache Busting for you Javascript and CSS
* Live Code reloading in development
* Super robust HTML formatting (HEEX) that ensures the HTML you produce is valid
* Internationalization and localization support (Gettext and CLDR)
* Great integration with VS Code
* Support for all the generic themes and templates you may found on the internet

And the main advantage of this approach is that you don't need to learn and rely on a new stack! Jekyll or Hugo are great, but... they are still *additional* tools that you need to master, with their own ecosystems, configuration details, plugins, caveats and so on. Plus if you need to go a little bit "offroad", like having something a little bit more complex than a blog with basic posts, you might end up struggling more than with a generic web framework.

So anyway, here is how to build a static site with Phoenix, and publish it on Github Pages through Github Action, with all the configuration and plumbing details.


Phoenix configuration
--------------------------------------

Generate a new phoenix site with minimal "dynamic" features (ecto / live)

```sh
mix phx.new ex_static --no-dashboard --no-ecto --no-live --no-mailer
```

In `prod.exs` file you will need to add the `cache_manifest_skip_vsn: true` option to the endpoint configuration
(cf: https://hexdocs.pm/phoenix/Phoenix.Endpoint.html#module-runtime-configuration)

```elixir
config :ex_static, ExStaticWeb.Endpoint,
  cache_static_manifest: "priv/static/cache_manifest.json",
  cache_manifest_skip_vsn: true # <- here
```

For a standard Phoenix app, we have a `runtime.exs` file to read environment variables and configure the application at runtime. But for a static site, there is no need for that. You can have reasonable default values in the `runtime.exs`, so that we don't have to specify them when generating the static site. So the `SECRET_KEY_BASE` and `PHX_HOST` for instance can be hardcoded in `runtime.exs`.

```elixir
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      "zigxtDrIex/lvxu3MG2JdrQANICNR6mzfI8PxXjk1uHi3jtVKB7cmATd8JlitRSm" # <- generated using mix phx.gen.secret
  ...

  host = System.get_env("PHX_HOST") || "localhost"
```

*Note: I'm hardcoding things like this, so that if I ever need to make my site dynamic after all, I can easily "convert it"...*

The build script
----------------------

The build script responsability is to generate the static pages of the site into a `public` folder at the root of the project. It will essentially:

1. compile and release the Elixir project
2. run the server
3. run `wget` to mirror the site into the `public` directory
4. stop the server

Here is the full `build.sh` script to place at the root of the project:

```sh
#!/bin/bash


# 0. Clean previous run
rm -rf public/

# 1. Compile and release the site
mix deps.get --only prod
MIX_ENV=prod mix deps.compile
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod mix compile
echo y |MIX_ENV=prod mix release

# 2. Start the server
_build/prod/rel/ex_static/bin/ex_static daemon
sleep 2

# 3. Mirror the site
# cf Wget options: https://www.man7.org/linux/man-pages/man1/wget.1.html
# -r (or --recursive) Recursive retrieving. The default maximum depth is 5
# -k (or --convert-links) will convert links in the web pages to relative after the download finishes
# -E (or --adjust-extension) If a file of type application/xhtml+xml or text/html is
#   downloaded and the URL does not end with the regexp
#   \.[Hh][Tt][Mm][Ll]?, this option will cause the suffix .html
#   to be appended to the local filename.
# -P (or --directory-prefix) the directory where all other files and subdirectories will be saved to
# --no-host-directories Disable generation of host-prefixed directories
#   (no additional http://localhost:4000/ directory created,
#   files will be saved directly in the directory specified in the -P argument)
wget -r -k -E -P public/ --no-host-directories http://localhost:4000/

# 4. Stop the server
_build/prod/rel/ex_static/bin/ex_static stop
```

Change the file permission to allow it's execution:

```sh
chmod +x build.sh
```

And... thats's it! Running this script will generate the static site in the `public/` directory. You can already upload the whole directory to your host server, Netlify or Github Page environment manually.


Publish to Github pages using Github Action
----------------------------------------------

The next improvement is to automate the publishing process. So lets publish it on every push on Github Pages with a Github Action workflow. This suppose you already have a git repository and a basic Github setup (you might need to activate Github Pages and the "Deploy from a branch: gh-pages" option in the settings of the project).

Add the build artefacts to the `.gitignore` file to avoid commiting unwanted files to your source repository:

```
# Ignore directory where the site is generated
/public

# Ignore digested assets cache
/priv/static/**/*.gz
/priv/static/**/*-????????????????????????????????.*
```

And add this `.github/workflows/gh-pages.yml` workflow file into your project:

```yml
name: Deploy to GitHub Pages

on:
  push:
    branches:
      - main  # Set a branch name to trigger deployment
  pull_request:

jobs:
  deploy:
    runs-on: ubuntu-22.04
    permissions:
      contents: write
    steps:
      # Step: Setup Elixir + Erlang image as the base.
      - name: Set up Elixir
        uses: erlef/setup-beam@v1
        with:
          otp-version: '26.1.2'
          elixir-version: '1.15.7'
      - uses: actions/checkout@v3

      # Step: Define how to cache deps. Restores existing cache if present.
      - name: Cache deps
        id: cache-deps
        uses: actions/cache@v3
        env:
          cache-name: cache-elixir-deps
        with:
          path: deps
          key: ${{ runner.os }}-mix-${{ env.cache-name }}-${{ hashFiles('**/mix.lock') }}
          restore-keys: |
            ${{ runner.os }}-mix-${{ env.cache-name }}-

      # Step: Define how to cache the `_build` directory. After the first run,
      # this speeds up tests runs a lot. This includes not re-compiling our
      # project's downloaded deps every run.
      - name: Cache compiled build
        id: cache-build
        uses: actions/cache@v3
        env:
          cache-name: cache-compiled-build
        with:
          path: _build
          key: ${{ runner.os }}-mix-${{ env.cache-name }}-${{ hashFiles('**/mix.lock') }}
          restore-keys: |
            ${{ runner.os }}-mix-${{ env.cache-name }}-
            ${{ runner.os }}-mix-

      # Step: Run app and build static site using the previous build script
      - name: Build site
        run: ./build.sh

      - name: Deploy to GitHub Pages
        uses: peaceiris/actions-gh-pages@v3
        # If you're changing the branch from main,
        # also change the `main` in `refs/heads/main`
        # below accordingly.
        if: github.ref == 'refs/heads/main'
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./public
```

And you should be done: a `git push` on the main branch should update your static site.
