defmodule FitTrackerzWeb.Member.ProgressLive do
  use FitTrackerzWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    actor = socket.assigns.current_user

    memberships = case FitTrackerz.Gym.list_active_memberships(actor.id, actor: actor, load: [:gym]) do
      {:ok, memberships} -> memberships
      _ -> []
    end

    case memberships do
      [] ->
        {:ok, assign(socket, page_title: "My Progress", no_gym: true)}

      memberships ->
        member_ids = Enum.map(memberships, & &1.id)
        today = Date.utc_today()
        thirty_days_ago = Date.add(today, -30)

        metrics = case FitTrackerz.Health.list_health_metrics(member_ids, actor: actor) do
          {:ok, m} -> m
          _ -> []
        end

        recent_metrics = Enum.filter(metrics, &(Date.compare(&1.recorded_on, thirty_days_ago) != :lt))

        {weight_change, latest_bmi} = calculate_weight_stats(recent_metrics)

        workout_logs = case FitTrackerz.Training.list_workout_log_dates(member_ids, actor: actor) do
          {:ok, logs} -> logs
          _ -> []
        end

        dates = workout_logs |> Enum.map(& &1.completed_on) |> Enum.uniq() |> Enum.sort(Date) |> Enum.reverse()
        current_streak = calculate_current_streak(dates, today)

        week_start = Date.add(today, -Date.day_of_week(today) + 1)
        food_logs = case FitTrackerz.Health.list_food_logs_by_range(member_ids, week_start, today, actor: actor) do
          {:ok, logs} -> logs
          _ -> []
        end

        calorie_target = case FitTrackerz.Training.list_diets_by_member(member_ids, actor: actor) do
          {:ok, [plan | _]} -> plan.calorie_target
          _ -> nil
        end

        daily_calories = food_logs
          |> Enum.group_by(& &1.logged_on)
          |> Enum.map(fn {date, entries} -> {date, Enum.reduce(entries, 0, &(&1.calories + &2))} end)
          |> Map.new()

        avg_calories = if map_size(daily_calories) > 0 do
          total = daily_calories |> Map.values() |> Enum.sum()
          div(total, map_size(daily_calories))
        else
          0
        end

        all_logs = case FitTrackerz.Training.list_workout_logs(member_ids, actor: actor) do
          {:ok, logs} -> logs
          _ -> []
        end

        prs = calculate_prs(all_logs)

        chart_metrics = recent_metrics |> Enum.sort_by(& &1.recorded_on, Date)
        weight_chart = weight_chart_config(chart_metrics)
        calorie_chart = calorie_chart_config(daily_calories, week_start, today, calorie_target)

        {:ok,
         assign(socket,
           page_title: "My Progress",
           no_gym: false,
           weight_change: weight_change,
           latest_bmi: latest_bmi,
           current_streak: current_streak,
           avg_calories: avg_calories,
           calorie_target: calorie_target,
           weight_chart: Jason.encode!(weight_chart),
           calorie_chart: Jason.encode!(calorie_chart),
           prs: Enum.take(prs, 6),
           has_metrics: chart_metrics != []
         )}
    end
  end

  defp calculate_weight_stats([]), do: {nil, nil}
  defp calculate_weight_stats(metrics) do
    sorted = Enum.sort_by(metrics, & &1.recorded_on, Date)
    first = List.first(sorted)
    last = List.last(sorted)

    change = if first && last && first.id != last.id do
      Decimal.sub(last.weight_kg, first.weight_kg) |> Decimal.to_float() |> Float.round(1)
    else
      nil
    end

    {change, last.bmi}
  end

  defp calculate_current_streak([], _today), do: 0
  defp calculate_current_streak([latest | rest], today) do
    diff = Date.diff(today, latest)
    if diff > 1, do: 0, else: count_consecutive([latest | rest], 1)
  end

  defp count_consecutive([_], count), do: count
  defp count_consecutive([a, b | rest], count) do
    if Date.diff(a, b) == 1, do: count_consecutive([b | rest], count + 1), else: count
  end

  defp calculate_prs(logs) do
    logs
    |> Enum.flat_map(fn log -> log.entries || [] end)
    |> Enum.filter(& &1.weight_kg)
    |> Enum.group_by(& &1.exercise_name)
    |> Enum.map(fn {name, entries} ->
      best = Enum.max_by(entries, &Decimal.to_float(&1.weight_kg))
      %{name: name, weight: Decimal.to_string(best.weight_kg, :normal)}
    end)
    |> Enum.sort_by(& &1.name)
  end

  defp weight_chart_config([]) do
    %{type: "line", data: %{labels: [], datasets: []}, options: %{scales: %{x: %{}, y: %{}}}}
  end

  defp weight_chart_config(metrics) do
    labels = Enum.map(metrics, &Calendar.strftime(&1.recorded_on, "%b %d"))
    data = Enum.map(metrics, &Decimal.to_float(&1.weight_kg))

    %{
      type: "line",
      data: %{
        labels: labels,
        datasets: [%{
          label: "Weight (kg)",
          data: data,
          borderColor: "rgb(34, 197, 94)",
          backgroundColor: "rgba(34, 197, 94, 0.1)",
          fill: true,
          tension: 0.3,
          pointRadius: 4
        }]
      },
      options: %{scales: %{x: %{}, y: %{}}}
    }
  end

  defp calorie_chart_config(daily_calories, week_start, today, calorie_target) do
    days = Enum.map(0..6, fn i -> Date.add(week_start, i) end)
    labels = Enum.map(days, &Calendar.strftime(&1, "%a"))
    data = Enum.map(days, fn d ->
      if Date.compare(d, today) != :gt, do: Map.get(daily_calories, d, 0), else: 0
    end)

    datasets = [%{
      label: "Calories",
      data: data,
      backgroundColor: "rgba(245, 158, 11, 0.5)",
      borderColor: "rgb(245, 158, 11)",
      borderWidth: 1,
      borderRadius: 4
    }]

    datasets = if calorie_target do
      target_line = %{
        label: "Target",
        data: Enum.map(days, fn _ -> calorie_target end),
        type: "line",
        borderColor: "rgba(255, 255, 255, 0.3)",
        borderDash: [5, 5],
        pointRadius: 0,
        fill: false
      }
      datasets ++ [target_line]
    else
      datasets
    end

    %{
      type: "bar",
      data: %{labels: labels, datasets: datasets},
      options: %{scales: %{x: %{}, y: %{beginAtZero: true}}}
    }
  end

  defp bmi_category(nil), do: ""
  defp bmi_category(bmi) do
    val = Decimal.to_float(bmi)
    cond do
      val < 18.5 -> "Underweight"
      val < 25.0 -> "Normal"
      val < 30.0 -> "Overweight"
      true -> "Obese"
    end
  end

  defp format_bmi(nil), do: "--"
  defp format_bmi(bmi), do: Decimal.to_string(bmi, :normal)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="space-y-8">
        <div class="flex items-center gap-3">
          <Layouts.back_button />
          <div>
            <h1 class="text-2xl sm:text-3xl font-brand">My Progress</h1>
            <p class="text-base-content/50 mt-1">Track your fitness journey over time.</p>
          </div>
        </div>

        <%= if @no_gym do %>
          <div class="card bg-base-200/50 border border-base-300/50" id="no-gym-card">
            <div class="card-body items-center text-center p-8">
              <.icon name="hero-building-office-2" class="size-8 text-warning" />
              <h2 class="text-lg font-bold mt-4">No Gym Membership</h2>
            </div>
          </div>
        <% else %>
          <%!-- Stat Cards --%>
          <div class="grid grid-cols-2 lg:grid-cols-4 gap-4">
            <div class="card bg-base-200/50 border border-base-300/50" id="stat-weight">
              <div class="card-body p-4">
                <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">Weight Change</p>
                <p class="text-2xl font-black mt-1">
                  <%= if @weight_change do %>
                    <span class={if @weight_change < 0, do: "text-success", else: "text-warning"}>
                      {if @weight_change < 0, do: "", else: "+"}{@weight_change} kg
                    </span>
                  <% else %>
                    <span class="text-base-content/30">--</span>
                  <% end %>
                </p>
                <p class="text-xs text-base-content/40 mt-1">Last 30 days</p>
              </div>
            </div>
            <div class="card bg-base-200/50 border border-base-300/50" id="stat-bmi">
              <div class="card-body p-4">
                <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">Current BMI</p>
                <p class="text-2xl font-black text-info mt-1">{format_bmi(@latest_bmi)}</p>
                <p class="text-xs text-base-content/40 mt-1">{bmi_category(@latest_bmi)}</p>
              </div>
            </div>
            <div class="card bg-base-200/50 border border-base-300/50" id="stat-streak">
              <div class="card-body p-4">
                <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">Workout Streak</p>
                <p class="text-2xl font-black text-accent mt-1">{@current_streak} days</p>
                <p class="text-xs text-base-content/40 mt-1">Current streak</p>
              </div>
            </div>
            <div class="card bg-base-200/50 border border-base-300/50" id="stat-calories">
              <div class="card-body p-4">
                <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider">Avg Calories</p>
                <p class="text-2xl font-black text-warning mt-1">{@avg_calories}</p>
                <p class="text-xs text-base-content/40 mt-1">
                  <%= if @calorie_target do %>
                    / {@calorie_target} target
                  <% else %>
                    no target set
                  <% end %>
                </p>
              </div>
            </div>
          </div>

          <%!-- Charts --%>
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <div class="card bg-base-200/50 border border-base-300/50" id="weight-chart-card">
              <div class="card-body p-5">
                <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
                  <.icon name="hero-chart-bar-solid" class="size-5 text-success" /> Weight Trend
                </h2>
                <%= if @has_metrics do %>
                  <div id="weight-chart" phx-hook="ChartHook" data-chart={@weight_chart} phx-update="ignore" style="height: 250px;">
                    <canvas></canvas>
                  </div>
                <% else %>
                  <div class="flex items-center justify-center h-[250px]">
                    <p class="text-sm text-base-content/40">No health data yet. Start logging at /member/health</p>
                  </div>
                <% end %>
              </div>
            </div>
            <div class="card bg-base-200/50 border border-base-300/50" id="calorie-chart-card">
              <div class="card-body p-5">
                <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
                  <.icon name="hero-fire-solid" class="size-5 text-warning" /> This Week's Calories
                </h2>
                <div id="calorie-chart" phx-hook="ChartHook" data-chart={@calorie_chart} phx-update="ignore" style="height: 250px;">
                  <canvas></canvas>
                </div>
              </div>
            </div>
          </div>

          <%!-- Recent PRs --%>
          <%= if @prs != [] do %>
            <div class="card bg-base-200/50 border border-base-300/50" id="prs-card">
              <div class="card-body p-5">
                <h2 class="text-lg font-bold flex items-center gap-2 mb-4">
                  <span class="text-xl">&#127942;</span> Personal Records
                </h2>
                <div class="flex flex-wrap gap-3">
                  <%= for pr <- @prs do %>
                    <div class="px-4 py-2 rounded-lg bg-warning/10 border border-warning/20">
                      <span class="font-bold text-sm">{pr.name}</span>
                      <span class="text-sm text-warning ml-2">{pr.weight} kg</span>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>
    </Layouts.app>
    """
  end
end
