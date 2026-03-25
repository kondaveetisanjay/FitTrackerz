defmodule FitTrackerzWeb.Trainer.ReportsLive do
  use FitTrackerzWeb, :live_view

  alias FitTrackerzWeb.Layouts

  @reports [
    %{type: "my_clients", name: "My Clients", desc: "Your assigned clients overview", icon: "hero-user-group-solid"},
    %{type: "client_attendance", name: "Client Attendance", desc: "Check-in records for your clients", icon: "hero-clipboard-document-check-solid"},
    %{type: "client_subscriptions", name: "Client Subscriptions", desc: "Subscription status of your clients", icon: "hero-credit-card-solid"},
    %{type: "workout_plans", name: "Workout Plans", desc: "Workout plans you've created", icon: "hero-fire-solid"},
    %{type: "diet_plans", name: "Diet Plans", desc: "Diet plans you've assigned", icon: "hero-heart-solid"},
    %{type: "my_classes", name: "My Classes", desc: "Classes you've taught", icon: "hero-calendar-days-solid"}
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
      <div class="space-y-6">
        <%!-- Header --%>
        <div>
          <div class="flex items-center gap-3 mb-1">
            <.link navigate="/trainer" class="btn btn-ghost btn-sm btn-circle">
              <.icon name="hero-arrow-left-mini" class="size-4" />
            </.link>
            <h1 class="text-2xl sm:text-3xl font-brand">Reports</h1>
          </div>
          <p class="text-base-content/50 ml-12">Generate and export detailed reports</p>
        </div>

        <%!-- Reports --%>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          <.link
            :for={report <- @reports}
            navigate={"/trainer/reports/#{report.type}"}
            class="card bg-base-200/50 border border-base-300/50 hover:border-primary/30 transition-colors cursor-pointer"
          >
            <div class="card-body p-5">
              <div class="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center mb-3">
                <.icon name={report.icon} class="size-5 text-primary" />
              </div>
              <h3 class="font-semibold">{report.name}</h3>
              <p class="text-sm text-base-content/50 mt-1">{report.desc}</p>
            </div>
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
