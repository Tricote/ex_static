defmodule ExStaticWeb.BlogHTML do
  use ExStaticWeb, :html

  alias ExStaticWeb.TocComponent

  embed_templates "blog_html/*"
end
