# fetch-favicon

Fetch a favicon with multiple fallbacks.

**Full online documentation is available [here](https://hexdocs.pm/fetch_favicon/FetchFavicon.html).**

**You can find the package on Hex [here](https://hex.pm/packages/fetch_favicon).**

For `example.com` it will first try `example.com/favicon.ico`, then it will try to find the icon file path in the HTML, and if it does, try to fetch that icon. If both fail, then it will query `https://www.google.com/s2/favicons?domain=example.com`

The image itself is returned.

## To use

``` elixir
case FetchFavicon.fetch("google.com") do
  {:ok, image} -> use_image(image)
  {:error, error_message} -> use_error(error_message)
end
```
