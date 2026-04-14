defmodule FitTrackerzWeb.FeedbackComponents do
  @moduledoc """
  Feedback and state components — skeleton loaders, spinners,
  progress bars, alerts, confirm dialogs, and step indicators.
  """
  use Phoenix.Component

  import FitTrackerzWeb.CoreComponents

  alias Phoenix.LiveView.JS

  # ────────────────────────────────────────────────────────
  # Skeleton Loader
  # ────────────────────────────────────────────────────────

  @doc """
  Renders skeleton loading placeholders that match content shape.

  ## Examples

      <.skeleton type="stat" />
      <.skeleton type="table" rows={5} />
      <.skeleton type="card" />
      <.skeleton type="text" rows={3} />
  """
  attr :type, :string, default: "text", values: ~w(text card table stat)
  attr :rows, :integer, default: 3, doc: "number of rows for text/table skeletons"

  def skeleton(%{type: "stat"} = assigns) do
    ~H"""
    <div class="bg-base-100 rounded-2xl border border-base-300/50 p-5 animate-pulse">
      <div class="flex items-center justify-between mb-3">
        <div class="w-10 h-10 rounded-xl skeleton-shimmer"></div>
      </div>
      <div class="h-7 w-20 skeleton-shimmer mb-1.5"></div>
      <div class="h-4 w-28 skeleton-shimmer"></div>
    </div>
    """
  end

  def skeleton(%{type: "card"} = assigns) do
    ~H"""
    <div class="bg-base-100 rounded-2xl border border-base-300/50 overflow-hidden animate-pulse">
      <div class="px-5 py-4 border-b border-base-300/50 flex items-center gap-3">
        <div class="h-5 w-32 skeleton-shimmer"></div>
      </div>
      <div class="p-5 space-y-3">
        <div class="h-4 w-full skeleton-shimmer"></div>
        <div class="h-4 w-3/4 skeleton-shimmer"></div>
        <div class="h-4 w-1/2 skeleton-shimmer"></div>
      </div>
    </div>
    """
  end

  def skeleton(%{type: "table"} = assigns) do
    ~H"""
    <div class="animate-pulse">
      <div class="flex gap-4 mb-3 px-2">
        <div class="h-4 w-24 skeleton-shimmer"></div>
        <div class="h-4 w-32 skeleton-shimmer"></div>
        <div class="h-4 w-20 skeleton-shimmer"></div>
        <div class="h-4 w-16 skeleton-shimmer"></div>
      </div>
      <div :for={_ <- 1..@rows} class="flex gap-4 py-3.5 px-2 border-b border-base-300/30">
        <div class="h-4 w-24 skeleton-shimmer"></div>
        <div class="h-4 w-32 skeleton-shimmer"></div>
        <div class="h-4 w-20 skeleton-shimmer"></div>
        <div class="h-4 w-16 skeleton-shimmer"></div>
      </div>
    </div>
    """
  end

  # Default: text skeleton
  def skeleton(assigns) do
    ~H"""
    <div class="animate-pulse space-y-2.5">
      <div :for={i <- 1..@rows} class={[
        "h-4 skeleton-shimmer",
        i == @rows && "w-2/3",
        i != @rows && "w-full"
      ]}></div>
    </div>
    """
  end

  # ────────────────────────────────────────────────────────
  # Loading Spinner
  # ────────────────────────────────────────────────────────

  @doc """
  Renders an inline loading spinner.

  ## Examples

      <.loading_spinner />
      <.loading_spinner size="lg" text="Loading members..." />
  """
  attr :size, :string, default: "md", values: ~w(sm md lg)
  attr :text, :string, default: nil

  def loading_spinner(assigns) do
    size_class = %{
      "sm" => "loading-sm",
      "md" => "loading-md",
      "lg" => "loading-lg"
    }

    assigns = assign(assigns, :size_class, Map.get(size_class, assigns.size, "loading-md"))

    ~H"""
    <div class="flex items-center justify-center gap-3 py-8">
      <span class={["loading loading-spinner text-primary", @size_class]}></span>
      <span :if={@text} class="text-sm text-base-content/60">{@text}</span>
    </div>
    """
  end

  # ────────────────────────────────────────────────────────
  # Progress Bar
  # ────────────────────────────────────────────────────────

  @doc """
  Renders a progress bar.

  ## Examples

      <.progress_bar value={75} color="primary" label="Workout Progress" />
  """
  attr :value, :integer, required: true, doc: "0-100 percentage"
  attr :color, :string, default: "primary", values: ~w(primary secondary accent success warning error info)
  attr :label, :string, default: nil
  attr :show_percentage, :boolean, default: true

  def progress_bar(assigns) do
    color_class = %{
      "primary" => "bg-primary",
      "secondary" => "bg-secondary",
      "accent" => "bg-accent",
      "success" => "bg-success",
      "warning" => "bg-warning",
      "error" => "bg-error",
      "info" => "bg-info"
    }

    clamped = max(0, min(100, assigns.value))

    assigns =
      assigns
      |> assign(:bar_color, Map.get(color_class, assigns.color, "bg-primary"))
      |> assign(:clamped, clamped)

    ~H"""
    <div>
      <div :if={@label || @show_percentage} class="flex items-center justify-between mb-1.5">
        <span :if={@label} class="text-sm font-medium">{@label}</span>
        <span :if={@show_percentage} class="text-xs text-base-content/50">{@clamped}%</span>
      </div>
      <div class="w-full h-2 bg-base-300/50 rounded-full overflow-hidden">
        <div
          class={["h-full rounded-full transition-all duration-500", @bar_color]}
          style={"width: #{@clamped}%"}
        >
        </div>
      </div>
    </div>
    """
  end

  # ────────────────────────────────────────────────────────
  # Alert
  # ────────────────────────────────────────────────────────

  @doc """
  Renders an inline alert message.

  ## Examples

      <.alert variant="info">Your subscription expires in 3 days.</.alert>
      <.alert variant="error" dismissible>Something went wrong.</.alert>
  """
  attr :variant, :string, default: "info", values: ~w(info success warning error)
  attr :dismissible, :boolean, default: false
  attr :id, :string, default: nil

  slot :inner_block, required: true

  def alert(assigns) do
    assigns = assign_new(assigns, :id, fn -> "alert-#{System.unique_integer([:positive])}" end)

    variant_class = %{
      "info" => "alert-info",
      "success" => "alert-success",
      "warning" => "alert-warning",
      "error" => "alert-error"
    }

    icon_name = %{
      "info" => "hero-information-circle",
      "success" => "hero-check-circle",
      "warning" => "hero-exclamation-triangle",
      "error" => "hero-exclamation-circle"
    }

    assigns =
      assigns
      |> assign(:variant_class, Map.get(variant_class, assigns.variant, "alert-info"))
      |> assign(:icon_name, Map.get(icon_name, assigns.variant, "hero-information-circle"))

    ~H"""
    <div id={@id} class={["alert rounded-xl", @variant_class]} role="alert">
      <.icon name={@icon_name} class="size-5 shrink-0" />
      <div class="flex-1 text-sm">
        {render_slot(@inner_block)}
      </div>
      <button
        :if={@dismissible}
        type="button"
        class="btn btn-ghost btn-xs btn-circle"
        phx-click={JS.hide(to: "##{@id}")}
        aria-label="Dismiss"
      >
        <.icon name="hero-x-mark" class="size-4" />
      </button>
    </div>
    """
  end

  # ────────────────────────────────────────────────────────
  # Confirm Dialog
  # ────────────────────────────────────────────────────────

  @doc """
  Renders a confirmation dialog for destructive actions.

  ## Examples

      <.confirm_dialog
        id="delete-member"
        title="Delete Member"
        message="This action cannot be undone."
        confirm_text="Delete"
        variant="danger"
        on_confirm="delete_member"
      />
  """
  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :message, :string, required: true
  attr :confirm_text, :string, default: "Confirm"
  attr :cancel_text, :string, default: "Cancel"
  attr :variant, :string, default: "danger", values: ~w(danger warning primary)
  attr :on_confirm, :string, required: true, doc: "phx-click event on confirm"

  def confirm_dialog(assigns) do
    btn_class = %{
      "danger" => "btn-error",
      "warning" => "btn-warning",
      "primary" => "btn-primary"
    }

    icon_name = %{
      "danger" => "hero-exclamation-triangle",
      "warning" => "hero-exclamation-triangle",
      "primary" => "hero-question-mark-circle"
    }

    assigns =
      assigns
      |> assign(:btn_class, Map.get(btn_class, assigns.variant, "btn-error"))
      |> assign(:icon_name, Map.get(icon_name, assigns.variant, "hero-exclamation-triangle"))

    ~H"""
    <div id={@id} class="hidden fixed inset-0 z-50">
      <div class="fixed inset-0 bg-black/50 backdrop-blur-sm" phx-click={JS.hide(to: "##{@id}")}></div>
      <div class="fixed inset-0 overflow-y-auto">
        <div class="flex min-h-full items-center justify-center p-4">
          <div class="relative w-full max-w-sm bg-base-100 rounded-2xl shadow-2xl p-6 text-center">
            <div class="w-12 h-12 rounded-full bg-error/10 flex items-center justify-center mx-auto mb-4">
              <.icon name={@icon_name} class="size-6 text-error" />
            </div>
            <h3 class="text-lg font-semibold mb-2">{@title}</h3>
            <p class="text-sm text-base-content/60 mb-6">{@message}</p>
            <div class="flex gap-3 justify-center">
              <button
                type="button"
                class="btn btn-ghost"
                phx-click={JS.hide(to: "##{@id}")}
              >
                {@cancel_text}
              </button>
              <button
                type="button"
                class={["btn", @btn_class]}
                phx-click={JS.push(@on_confirm) |> JS.hide(to: "##{@id}")}
              >
                {@confirm_text}
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ────────────────────────────────────────────────────────
  # Step Indicator
  # ────────────────────────────────────────────────────────

  @doc """
  Renders a step progress indicator for wizards and multi-step flows.

  ## Examples

      <.step_indicator
        steps={["Details", "Location", "Plans"]}
        current={1}
      />
  """
  attr :steps, :list, required: true, doc: "list of step label strings"
  attr :current, :integer, required: true, doc: "zero-based current step index"

  def step_indicator(assigns) do
    ~H"""
    <div class="flex items-center justify-center">
      <ol class="flex items-center gap-2">
        <%= for {label, idx} <- Enum.with_index(@steps) do %>
          <li class="flex items-center gap-2">
            <div class={[
              "w-8 h-8 rounded-full flex items-center justify-center text-sm font-semibold transition-colors",
              idx < @current && "bg-primary text-primary-content",
              idx == @current && "bg-primary text-primary-content ring-4 ring-primary/20",
              idx > @current && "bg-base-300 text-base-content/40"
            ]}>
              <.icon :if={idx < @current} name="hero-check-mini" class="size-4" />
              <span :if={idx >= @current}>{idx + 1}</span>
            </div>
            <span class={[
              "text-sm font-medium hidden sm:inline",
              idx == @current && "text-base-content",
              idx != @current && "text-base-content/50"
            ]}>
              {label}
            </span>
            <div :if={idx < length(@steps) - 1} class="w-8 sm:w-12 h-px bg-base-300 mx-1"></div>
          </li>
        <% end %>
      </ol>
    </div>
    """
  end
end
