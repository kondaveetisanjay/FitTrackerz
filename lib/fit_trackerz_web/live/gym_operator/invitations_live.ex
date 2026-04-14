defmodule FitTrackerzWeb.GymOperator.InvitationsLive do
  use FitTrackerzWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    case FitTrackerz.Gym.list_gyms_by_owner(actor.id, actor: actor) do
      {:ok, [gym | _]} ->
        member_invitations = case FitTrackerz.Gym.list_pending_member_invitations_by_gym(gym.id, actor: actor, load: [:invited_by]) do
          {:ok, invitations} -> invitations
          _ -> []
        end

        {:ok,
         assign(socket,
           page_title: "Invitations",
           gym: gym,
           member_invitations: member_invitations
         )}

      _ ->
        {:ok,
         assign(socket,
           page_title: "Invitations",
           gym: nil,
           member_invitations: []
         )}
    end
  end

  defp status_variant(:pending), do: "warning"
  defp status_variant(:accepted), do: "success"
  defp status_variant(:rejected), do: "error"
  defp status_variant(:expired), do: "neutral"
  defp status_variant(_), do: "neutral"

  defp format_date(%DateTime{} = dt) do
    Calendar.strftime(dt, "%b %d, %Y %I:%M %p")
  end

  defp format_date(_), do: "--"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-6">
        <.page_header title="Invitations" subtitle="Track all member invitations." back_path="/gym" />

        <%= if @gym == nil do %>
          <.empty_state icon="hero-building-office-solid" title="No Gym Found" subtitle="You need to create a gym first before viewing invitations.">
            <:action>
              <.button variant="primary" size="sm" icon="hero-plus-mini" navigate="/gym/setup">Setup Gym</.button>
            </:action>
          </.empty_state>
        <% else %>
          <.card title="Member Invitations" subtitle={"#{length(@member_invitations)} invitations"}>
            <:header_actions>
              <.button variant="ghost" size="sm" icon="hero-plus-mini" navigate="/gym/members">Invite</.button>
            </:header_actions>
            <%= if @member_invitations == [] do %>
              <.empty_state icon="hero-envelope" title="No Invitations" subtitle="No member invitations sent yet." />
            <% else %>
              <.data_table id="member-invitations-table" rows={@member_invitations} row_id={fn inv -> "member-inv-#{inv.id}" end}>
                <:col :let={inv} label="Email">
                  <span class="font-medium">{inv.invited_email}</span>
                </:col>
                <:col :let={inv} label="Status">
                  <.badge variant={status_variant(inv.status)}>{Phoenix.Naming.humanize(inv.status)}</.badge>
                </:col>
                <:col :let={inv} label="Invited By">
                  {inv.invited_by.name}
                </:col>
                <:col :let={inv} label="Date">
                  <span class="text-sm text-base-content/60">{format_date(inv.inserted_at)}</span>
                </:col>
              </.data_table>
            <% end %>
          </.card>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
