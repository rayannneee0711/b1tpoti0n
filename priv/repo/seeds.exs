# Development seed data
#
#     mix run priv/repo/seeds.exs

if Mix.env() == :prod do
  raise "Refusing to run seeds in production environment"
end

alias B1tpoti0n.Persistence.Repo
alias B1tpoti0n.Persistence.Schemas.{User, Whitelist}

# Test user with known passkey
{:ok, _user} =
  Repo.insert(%User{
    passkey: "00000000000000000000000000000001"
  })

# Whitelist common BitTorrent clients
clients = [
  {"-TR", "Transmission"},
  {"-qB", "qBittorrent"},
  {"-DE", "Deluge"},
  {"-UT", "uTorrent"},
  {"-lt", "libtorrent"},
  {"-LT", "libtorrent"},
  {"-AZ", "Azureus/Vuze"},
  {"-BT", "BitTorrent"},
  {"-WW", "WebTorrent"}
]

for {prefix, name} <- clients do
  Repo.insert!(%Whitelist{client_prefix: prefix, name: name})
end

IO.puts("Seeds completed: 1 user, #{length(clients)} whitelisted clients")
