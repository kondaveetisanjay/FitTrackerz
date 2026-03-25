defmodule FitTrackerzWeb.GymOperator.ReportsLive do
  use FitTrackerzWeb, :live_view

  alias FitTrackerzWeb.Layouts

  @member_reports [
    %{type: "active_members", name: "Active Members", desc: "Active vs inactive member breakdown", icon: "hero-user-group-solid"},
    %{type: "new_members", name: "New Members", desc: "Members who joined in the selected period", icon: "hero-user-plus-solid"},
    %{type: "revenue", name: "Revenue", desc: "Plan-wise revenue from paid subscriptions", icon: "hero-currency-rupee-solid"},
    %{type: "attendance", name: "Attendance", desc: "Member check-in records and trends", icon: "hero-clipboard-document-check-solid"},
    %{type: "subscription_status", name: "Subscription Status", desc: "Subscription status breakdown", icon: "hero-credit-card-solid"},
    %{type: "class_utilization", name: "Class Utilization", desc: "Class bookings vs capacity", icon: "hero-calendar-days-solid"},
    %{type: "payment_collection", name: "Payment Collection", desc: "Payment status breakdown with amounts", icon: "hero-banknotes-solid"},
    %{type: "member_retention", name: "Member Retention", desc: "Active vs churned members", icon: "hero-arrow-trending-up-solid"}
  ]

  @trainer_reports [
    %{type: "trainer_overview", name: "Trainer Overview", desc: "Summary of all trainers' performance", icon: "hero-academic-cap-solid"},
    %{type: "trainer_client_load", name: "Trainer Client Load", desc: "Client distribution across trainers", icon: "hero-users-solid"},
    %{type: "trainer_class_performance", name: "Trainer Class Performance", desc: "Class teaching performance per trainer", icon: "hero-chart-bar-solid"},
    %{type: "trainer_attendance", name: "Trainer Attendance Impact", desc: "Client attendance per trainer", icon: "hero-clipboard-document-check-solid"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Reports",
       member_reports: @member_reports,
       trainer_reports: @trainer_reports
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
            <.link navigate="/gym" class="btn btn-ghost btn-sm btn-circle">
              <.icon name="hero-arrow-left-mini" class="size-4" />
            </.link>
            <h1 class="text-2xl sm:text-3xl font-brand">Reports</h1>
          </div>
          <p class="text-base-content/50 ml-12">Generate and export detailed reports</p>
        </div>

        <%!-- Member Reports --%>
        <div>
          <h2 class="text-lg font-semibold mb-4">Member Reports</h2>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <.link
              :for={report <- @member_reports}
              navigate={"/gym/reports/#{report.type}"}
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

        <%!-- Trainer Performance Reports --%>
        <div>
          <h2 class="text-lg font-semibold mb-4">Trainer Performance Reports</h2>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <.link
              :for={report <- @trainer_reports}
              navigate={"/gym/reports/#{report.type}"}
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
      </div>
    </Layouts.app>
    """
  end
end
