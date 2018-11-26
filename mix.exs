defmodule Bite.MixProject do
  use Mix.Project

  def project do
    [
      app: :bite,
      name: "Bite",
      description: "A byte-wise convenience library.",
      version: "0.1.1",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.html": :test,
        credo: :test,
        bless: :test
      ],
      test_coverage: [tool: ExCoveralls],
      aliases: aliases(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:private, "~> 0.1.1"},
      {:excoveralls, "~> 0.7", only: :test},
      {:credo, "~> 0.9", only: :test, runtime: false},
      {:dialyxir, "~> 0.5", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.19.1", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      name: "bite",
      files: ~w(lib README.md mix.exs .formatter.exs LICENSE),
      licenses: ["BSD3"],
      links: %{"GitHub" => "https://github.com/the-mikedavis/bite.git"}
    ]
  end

  defp aliases do
    [
      bless: [&bless/1]
    ]
  end

  defp bless(_) do
    [
      {"format", ["--check-formatted"]},
      {"compile", ["--warnings-as-errors", "--force"]},
      {"coveralls.html", []},
      {"credo", []},
      {"dialyzer", []}
    ]
    |> Enum.each(fn {task, args} ->
      IO.ANSI.format([:cyan, "Running #{task} with args #{inspect(args)}"])
      |> IO.puts()

      Mix.Task.run(task, args)
    end)
  end
end
