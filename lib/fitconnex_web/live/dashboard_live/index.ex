defmodule FitconnexWeb.DashboardLive.Index do
  use FitconnexWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    redirect_path =
      case user.role do
        :platform_admin -> "/admin/dashboard"
        :gym_operator -> "/gym/dashboard"
        :member -> "/member/dashboard"
        _ -> "/member/dashboard"
      end

    {:ok, push_navigate(socket, to: redirect_path)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex items-center justify-center min-h-[50vh]">
      <span class="loading loading-spinner loading-lg"></span>
    </div>
    """
  end
end
