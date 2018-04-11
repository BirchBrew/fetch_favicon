defmodule FetchFaviconTest do
  use ExUnit.Case

  import Mock

  test "invalid html returned" do
    with_mock HTTPoison, get: fn _, _, _ -> "" end do
      assert {:error, _} = FetchFavicon.fetch("reddit.com")
    end
  end

  test "error returned" do
    with_mock HTTPoison, get: fn _, _, _ -> {:error, "error message"} end do
      assert {:error, _} = FetchFavicon.fetch("reddit.com")
    end
  end

  test "first call fails" do
    base_site_response = %HTTPoison.Response{
      body: "<html><link href=\"/custom/reddit/ico/path/icon.ico\" rel=\"shortcut icon\"></html>",
      headers: [],
      request_url: "",
      status_code: 200
    }

    image_response = %HTTPoison.Response{
      body: "some valid image",
      headers: [],
      request_url: "",
      status_code: 200
    }

    with_mock HTTPoison,
      get: fn url, _, _ ->
        case url do
          "reddit.com/favicon.ico" ->
            nil

          "reddit.com" ->
            {:ok, base_site_response}

          "reddit.com/custom/reddit/ico/path/icon.ico" ->
            {:ok, image_response}

          _ ->
            nil
        end
      end do
      assert {:ok, _} = FetchFavicon.fetch("reddit.com")
    end
  end

  test "first call fails, no image in image tag" do
    response = %HTTPoison.Response{
      body: "<html><rel=\"shortcut icon\"></html>",
      headers: [],
      request_url: "",
      status_code: 200
    }

    with_mock HTTPoison,
      get: fn url, _, _ ->
        case url do
          "reddit.com/favicon.ico" ->
            nil

          "reddit.com" ->
            {:ok, response}

          _ ->
            nil
        end
      end do
      assert {:error, _} = FetchFavicon.fetch("reddit.com")
    end
  end

  test "first call fails, no image tag" do
    response = %HTTPoison.Response{
      body: "<html></html>",
      headers: [],
      request_url: "",
      status_code: 200
    }

    with_mock HTTPoison,
      get: fn url, _, _ ->
        case url do
          "reddit.com/favicon.ico" ->
            nil

          "reddit.com" ->
            {:ok, response}

          _ ->
            nil
        end
      end do
      assert {:error, _} = FetchFavicon.fetch("reddit.com")
    end
  end

  test "first and second calls fail" do
    response = %HTTPoison.Response{
      body: "image",
      headers: [],
      request_url: "",
      status_code: 200
    }

    with_mock HTTPoison,
      get: fn url, _, _ ->
        case url do
          "reddit.com/favicon.ico" ->
            nil

          "reddit.com" ->
            nil

          "https://www.google.com/s2/favicons?domain=reddit.com" ->
            {:ok, response}

          _ ->
            nil
        end
      end do
      assert {:ok, _} = FetchFavicon.fetch("reddit.com")
    end
  end
end
