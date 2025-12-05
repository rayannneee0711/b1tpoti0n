defmodule B1tpoti0n.Persistence.Schemas.Snatch do
  @moduledoc """
  Schema for tracking torrent completions (snatches).

  Records when a user completes downloading a torrent and tracks
  their seedtime after completion. Used for hit-and-run detection.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias B1tpoti0n.Persistence.Schemas.{User, Torrent}

  @type t :: %__MODULE__{
          id: integer() | nil,
          user_id: integer() | nil,
          torrent_id: integer() | nil,
          completed_at: DateTime.t() | nil,
          seedtime: integer(),
          last_announce_at: DateTime.t() | nil,
          hnr: boolean(),
          user: User.t() | Ecto.Association.NotLoaded.t(),
          torrent: Torrent.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "snatches" do
    belongs_to :user, User
    belongs_to :torrent, Torrent
    field :completed_at, :utc_datetime
    field :seedtime, :integer, default: 0
    field :last_announce_at, :utc_datetime
    field :hnr, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(snatch, attrs) do
    snatch
    |> cast(attrs, [:user_id, :torrent_id, :completed_at, :seedtime, :last_announce_at, :hnr])
    |> validate_required([:user_id, :torrent_id, :completed_at])
    |> validate_number(:seedtime, greater_than_or_equal_to: 0)
    |> unique_constraint([:user_id, :torrent_id], name: :snatches_user_id_torrent_id_index)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:torrent_id)
  end

  @doc """
  Calculate the seed ratio for this snatch (seedtime / grace_period).
  """
  @spec seed_ratio(t(), non_neg_integer()) :: float()
  def seed_ratio(%__MODULE__{seedtime: seedtime}, required_seedtime) when required_seedtime > 0 do
    seedtime / required_seedtime
  end

  def seed_ratio(_, _), do: 0.0
end
