defmodule FetchFavicon do
  import Untangle
  @user_agent "Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:47.0) Gecko/20100101 Firefox/47.0"
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

  @doc """
  Fetch the binary contents of a favicon file for a domain 
  """
  def fetch(url) do
    get(url, true)
  end

  @doc """
  Get the URL contents of a favicon file for a domain (or fetch its binary contents by setting the fetch? param to true)
  """
  def get(url, fetch? \\ false) do
    {absolute_url, host} = process_uri(url)

    with {:ok, image} <-
           fetch_default(absolute_url, fetch?) || fetch_from_third_parties(host, fetch?) || fetch_from_html(absolute_url, fetch?) do
      {:ok, image}
    else
      e ->
        error(e, "failed to find favicon for #{url}")
    end
  end

  @doc """
  Find a favicon URL (or fetch its binary contents by setting the fetch? param to true)
  Parses an HTML page and tries to find a favicon in it (if provided), and otherwise tries other techniques
  """
  def find(url, html_body, fetch? \\ false) do
    with {:ok, image_or_url} <- parse(url, html_body, fetch?) || get(url, fetch?) do
      {:ok, image_or_url}
    else
      _ ->
        {:error, "failed to find favicon"}
    end
  end

  @doc """
  Parses an HTML page and tries to find a favicon URL in it
  """
  def parse(url, html_body, fetch? \\ false) do
    with icon_path when is_binary(icon_path) <- get_icon_path_html(html_body) do
      get_absolute_image_path(url, icon_path)
      |> check_url(fetch?)
    else
      _ -> nil
    end
  end

  defp fetch_default(url, fetch? \\ true) do
    URI.parse(url) |> URI.merge("/favicon.ico") |> to_string()
    |> check_url(fetch?)
  end

  defp fetch_from_html(url, fetch? \\ true) do
    with {:ok, body} <- get_html_from_url(url) do
      parse(url, body, fetch?)
    else
      _ -> nil
    end
  end

  def fetch_from_third_parties(url, fetch? \\ true) do
    fetch_from_duck_duck_go(url, fetch?) ||
             fetch_from_google(url, fetch?)
  end

  defp fetch_from_duck_duck_go(domain, fetch? \\ true) do
    check_url("https://icons.duckduckgo.com/ip3/#{domain}.ico", fetch?)
  end

  defp fetch_from_google(domain, fetch? \\ true) do
    check_url("https://www.google.com/s2/favicons?domain=#{domain}", fetch?)
  end

  defp get_icon_path_html(body) do
    case Floki.find(body, "link[rel=icon]") do
      [] ->
        case Floki.find(body, "link[rel*=icon]") do
          [] -> 
            nil

          links ->
            first_icon_from_links(links)
        end

      links ->
        first_icon_from_links(links)
    end
  end

  defp first_icon_from_links(links) do
    Floki.attribute(links, "href")
    |> List.first()

    # |> IO.inspect(label: "first_icon_from_links")
  end

  defp check_url(url, _fetch? = true), do: get_image_from_url(url)
  defp check_url(url, _), do: get_valid_image_url(url)

  defp get_image_from_url(url) do
    case get_html(url) do
      {:ok, %{body: ""}} ->
        nil

      {:ok, %{body: body, headers: headers_list}} ->
        case Enum.into(headers_list, %{}) do
          %{"content-encoding" => _encoding} -> nil
          %{"content-type" => "image" <> _} -> {:ok, body}
          _ -> nil
        end

      other ->
        debug(other, url)
        nil
    end
  end

  defp get_valid_image_url(url) do
    case get_headers(url) do
      {:ok, %{headers: headers_list}} ->
        # IO.inspect(headers_list)
        case Enum.into(headers_list, %{}) do
          %{"content-type" => "image" <> _} -> {:ok, url}
          _ -> nil
        end

      # |> IO.inspect(label: "get_valid_image_url")

      other ->
        debug(other, url)
        nil
    end
  end

  defp get_html_from_url(url) do
    case get_html(url) do
      {:ok, %{body: body, headers: headers_list}} ->

        case Enum.into(headers_list, %{}) do
          %{"content-type" => "text/html" <> _} -> {:ok, body}
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp get_html(url) do
    if full_uri?(url) do
      case {_code, response} =
             Req.get(
               url,
               user_agent: @user_agent,
               receive_timeout: @timeout_ms,
               max_redirects: 3,
               retry: false,
               adapter: Process.get(:req_adapter) || &Req.Steps.run_finch/1 # for mocks during testing
             ) do
        {:ok, %{status: 200}} -> {:ok, response}
        _ -> nil
      end
    end
  end

  defp get_headers(url) do
    if full_uri?(url)  do
      case {_code, response} =
             Req.head(
               url,
               user_agent: @user_agent,
               receive_timeout: @timeout_ms,
               max_redirects: 3,
               raw: true
             ) do
        {:ok, %{status: 200}} -> {:ok, response}
        _ -> nil
      end
    end
  end

  defp get_absolute_image_path(url, icon_path) do
    case URI.parse(url) do
      %{scheme: nil} ->
        icon_path

      %{host: nil} ->
        icon_path

      _ ->
        case URI.parse(icon_path) do
          %{scheme: nil} -> URI.merge(url, icon_path) |> to_string()
          %{host: nil} -> URI.merge(url, icon_path) |> to_string()
          _ -> icon_path
        end
    end
  end

  defp process_uri(url) do
    case URI.parse(url) do
      %{host: nil, path: path_as_host} -> {"http://#{path_as_host}", path_as_host}
      %{host: host} -> {url, host}
    end
  end

  defp full_uri?(url) do
    case URI.parse(url) do
      %{scheme: nil} -> false
      %{host: nil} -> false
      _ -> true
    end
  end
end
