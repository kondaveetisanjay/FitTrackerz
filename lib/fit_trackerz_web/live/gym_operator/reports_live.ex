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
    <Layouts.app flash={@flash} current_user={@current_user} unread_notification_count={assigns[:unread_notification_count] || 0}>
      <div class="space-y-6">
        <.page_header title="Reports" subtitle="Generate and export detailed reports" back_path="/gym/dashboard" />

        <.section title="Member Reports">
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <.link
              :for={report <- @member_reports}
              navigate={"/gym/reports/#{report.type}"}
              class="group"
            >
              <.card class="hover:border-primary/30 transition-colors cursor-pointer h-full">
                <div class="flex items-start gap-4">
                  <div class="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center shrink-0">
                    <.icon name={report.icon} class="size-5 text-primary" />
                  </div>
                  <div>
                    <h3 class="font-semibold">{report.name}</h3>
                    <p class="text-sm text-base-content/50 mt-1">{report.desc}</p>
                  </div>
                </div>
              </.card>
            </.link>
          </div>
        </.section>

        <.section title="Trainer Performance Reports">
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <.link
              :for={report <- @trainer_reports}
              navigate={"/gym/reports/#{report.type}"}
              class="group"
            >
              <.card class="hover:border-primary/30 transition-colors cursor-pointer h-full">
                <div class="flex items-start gap-4">
                  <div class="w-10 h-10 rounded-xl bg-primary/10 flex items-center justify-center shrink-0">
                    <.icon name={report.icon} class="size-5 text-primary" />
                  </div>
                  <div>
                    <h3 class="font-semibold">{report.name}</h3>
                    <p class="text-sm text-base-content/50 mt-1">{report.desc}</p>
                  </div>
                </div>
              </.card>
            </.link>
          </div>
        </.section>
      </div>
    </Layouts.app>
    """
  end
end
