defmodule FetchFavicon do
  @user_agent_pls_no_fbi "Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:47.0) Gecko/20100101 Firefox/47.0"
  @timeout_ms 3_000
  @moduledoc """
  Used to retrieve a favicon from a website.
  """

  @doc """
  Tries to obtain a favicon for the site.
  It first tries the url/favicon.ico (for speed).
  Then it tries to find a path to an icon in the HTML and then fetch that.
  Lastly it uses the google favicon service to retrieve a favicon.

  If you do not pass `http://` or `https://`, `http://` is assumed.

  Returns `{:ok, image}` if successful and `{:error, "failed to find image"}` if unsuccessful.

  """
  def fetch(url) do
    url = get_absolute_path(url)

    case fetch_default(url) || fetch_from_html(url) || fetch_from_google(url) do
      {:ok, image} -> {:ok, image}
      _ -> {:error, "failed to find image"}
    end
  end

  defp fetch_default(url) do
    favicon_url = URI.parse(url) |> URI.merge("/favicon.ico") |> to_string()
    fetch_html(favicon_url)
  end

  defp fetch_from_html(url) do
    with {:ok, body} <- fetch_html(url),
         {:ok, icon_path} <- get_icon_path_html(body),
         path = get_absolute_image_path(url, icon_path) do
      fetch_html(path)
    else
      _ -> nil
    end
  end

  defp fetch_from_google(url) do
    google_favicon_url = "https://www.google.com/s2/favicons?domain=#{url}"
    fetch_html(google_favicon_url)
  end

  defp get_absolute_image_path(url, icon_path) do
    case icon_path do
      "/" <> _ -> URI.merge(url, icon_path) |> to_string()
      _ -> icon_path
    end
  end

  defp get_icon_path_html(body) do
    case Floki.find(body, "link[rel*=icon]") do
      [] ->
        nil

      links ->
        [first_favicon_link | _others] = Floki.attribute(links, "href")
        {:ok, first_favicon_link}
    end
  end

  defp fetch_html(url) do
    case HTTPoison.get(
           url,
           %{"User-Agent" => @user_agent_pls_no_fbi},
           recv_timeout: @timeout_ms,
           follow_redirect: true
         ) do
      {:ok, %{status_code: 200, body: body}} -> {:ok, body}
      _ -> nil
    end
  end

  defp get_absolute_path(url) do
    case URI.parse(url) do
      %{host: nil, path: path} -> "http://#{path}"
      _ -> url
    end
  end
end
