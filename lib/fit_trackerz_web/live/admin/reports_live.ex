defmodule FitTrackerzWeb.Admin.ReportsLive do
  use FitTrackerzWeb, :live_view

  alias FitTrackerzWeb.Layouts

  @reports [
    %{type: "gyms", name: "Gyms", desc: "All registered gyms with status and metrics", icon: "hero-building-office-2-solid"},
    %{type: "members", name: "Members", desc: "All members across the platform", icon: "hero-user-group-solid"},
    %{type: "revenue", name: "Revenue", desc: "Platform-wide revenue by gym", icon: "hero-currency-rupee-solid"},
    %{type: "subscriptions", name: "Subscriptions", desc: "All subscriptions platform-wide", icon: "hero-credit-card-solid"},
    %{type: "trainers", name: "Trainers", desc: "All trainers across the platform", icon: "hero-academic-cap-solid"},
    %{type: "attendance", name: "Attendance", desc: "Platform-wide attendance records", icon: "hero-clipboard-document-check-solid"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Reports",
       reports: @reports
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.page_header title="Reports" subtitle="Generate and export detailed reports" back_path="/admin/dashboard" />

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        <.link
          :for={report <- @reports}
          navigate={"/admin/reports/#{report.type}"}
          class="group"
        >
          <.card class="h-full hover:border-primary/30 transition-colors cursor-pointer">
            <div class="flex items-start gap-4">
              <div class="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center shrink-0">
                <.icon name={report.icon} class="size-5 text-primary" />
              </div>
              <div class="min-w-0">
                <h3 class="font-semibold group-hover:text-primary transition-colors">{report.name}</h3>
                <p class="text-sm text-base-content/50 mt-1">{report.desc}</p>
              </div>
            </div>
          </.card>
        </.link>
      </div>
    </Layouts.app>
    """
  end
end
