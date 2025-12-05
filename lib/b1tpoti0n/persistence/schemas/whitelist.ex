defmodule B1tpoti0n.Persistence.Schemas.Whitelist do
  @moduledoc """
  Whitelist schema for allowed BitTorrent client prefixes.
  Peer IDs start with a client identifier (e.g., "-TR2940-" for Transmission).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          client_prefix: String.t() | nil,
          name: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "whitelist" do
    field :client_prefix, :string
    field :name, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(whitelist, attrs) do
    whitelist
    |> cast(attrs, [:client_prefix, :name])
    |> validate_required([:client_prefix, :name])
    |> validate_length(:client_prefix, min: 1, max: 8)
    |> unique_constraint(:client_prefix)
  end
end
