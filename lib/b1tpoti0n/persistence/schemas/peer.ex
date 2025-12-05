defmodule B1tpoti0n.Persistence.Schemas.Peer do
  @moduledoc """
  Peer schema for tracking active peers on torrents.
  Uses composite primary key (user_id, torrent_id).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          user_id: integer() | nil,
          torrent_id: integer() | nil,
          user: B1tpoti0n.Persistence.Schemas.User.t() | Ecto.Association.NotLoaded.t(),
          torrent: B1tpoti0n.Persistence.Schemas.Torrent.t() | Ecto.Association.NotLoaded.t(),
          ip: String.t() | nil,
          port: integer() | nil,
          peer_id: binary() | nil,
          left: integer() | nil,
          uploaded: integer(),
          downloaded: integer(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @primary_key false
  schema "peers" do
    belongs_to :user, B1tpoti0n.Persistence.Schemas.User, primary_key: true
    belongs_to :torrent, B1tpoti0n.Persistence.Schemas.Torrent, primary_key: true

    field :ip, :string
    field :port, :integer
    field :peer_id, :binary
    field :left, :integer
    field :uploaded, :integer, default: 0
    field :downloaded, :integer, default: 0

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(peer, attrs) do
    peer
    |> cast(attrs, [:user_id, :torrent_id, :ip, :port, :peer_id, :left, :uploaded, :downloaded])
    |> validate_required([:user_id, :torrent_id, :ip, :port])
    |> validate_number(:port, greater_than: 0, less_than: 65536)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:torrent_id)
  end
end
