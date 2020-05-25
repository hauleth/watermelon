defmodule Watermelon.MixProject do
  use Mix.Project

  def project do
    [
      app: :watermelon,
      description: "Super simple Gherkin features to ExUnit tests translator",
      version: version(),
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      elixirc_options: [
        warnings_as_errors: true
      ],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.html": :test,
        "coveralls.json": :test
      ],
      test_coverage: [tool: ExCoveralls]
    ]
  end

  defp version do
    case :file.consult('hex_metadata.config') do
      {:ok, data} ->
        {"version", version} = List.keyfind(data, "version", 0)
        version

      _ ->
        version =
          case System.cmd("git", ~w[describe --dirty=+dirty]) do
            {version, 0} ->
              String.trim(version)

            {_, code} ->
              Mix.shell().error("Git exited with code #{code}, falling back to 0.0.0")

              "0.0.0"
          end

        case Version.parse(version) do
          {:ok, %Version{pre: ["pre" <> _ | _]} = version} ->
            to_string(version)

          {:ok, %Version{pre: []} = version} ->
            to_string(version)

          {:ok, %Version{patch: patch, pre: pre} = version} ->
            to_string(%{version | patch: patch + 1, pre: ["dev" | pre]})

          :error ->
            Mix.shell().error("Failed to parse #{version}, falling back to 0.0.0")

            "0.0.0"
        end
    end
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:ex_unit, :logger]
    ]
  end

  defp package do
    [
      licenses: ["MPL-2.0"],
      links: %{
        "Github" => "https://github.com/hauleth/watermelon",
        "Gherkin Reference" => "https://docs.cucumber.io/gherkin/reference/"
      }
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:gherkin, "~> 1.6.0"},

      # Documentation
      {:ex_doc, ">= 0.0.0", only: [:dev], runtime: false},
      {:inch_ex, "~> 2.0", only: [:dev], runtime: false},

      # Development
      {:credo, ">= 0.0.0", only: [:dev], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.4", only: [:dev], runtime: false},

      # Testing
      {:stream_data, "~> 0.4.0", only: [:dev, :test]},
      {:excoveralls, "~> 0.10", only: [:test]}
    ]
  end
end
