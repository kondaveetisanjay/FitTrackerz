defmodule FitTrackerzWeb.LayoutComponents do
  @moduledoc """
  Layout components for page structure — page headers, stat cards, cards,
  tabs, sections, and multi-step wizards.
  """
  use Phoenix.Component

  import FitTrackerzWeb.CoreComponents

  alias Phoenix.LiveView.JS

  # ────────────────────────────────────────────────────────
  # Page Header
  # ────────────────────────────────────────────────────────

  @doc """
  Renders a consistent page header with title, subtitle, optional back nav, and action slot.

  ## Examples

      <.page_header title="Members" subtitle="Manage your gym members">
        <:actions>
          <.button icon="hero-plus">Add Member</.button>
        </:actions>
      </.page_header>
  """
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :back_path, :string, default: nil, doc: "path for back navigation link"

  slot :actions

  def page_header(assigns) do
    ~H"""
    <div class="mb-8">
      <div class="flex items-start sm:items-center justify-between gap-4 flex-col sm:flex-row">
        <div class="flex items-center gap-3">
          <.link :if={@back_path} navigate={@back_path} class="btn btn-ghost btn-sm btn-circle shrink-0">
            <.icon name="hero-arrow-left" class="size-5" />
          </.link>
          <div>
            <h1 class="text-2xl sm:text-3xl font-brand font-bold">{@title}</h1>
            <p :if={@subtitle} class="text-sm text-base-content/60 mt-1">{@subtitle}</p>
          </div>
        </div>
        <div :if={@actions != []} class="flex items-center gap-2 shrink-0">
          {render_slot(@actions)}
        </div>
      </div>
    </div>
    """
  end

  # ────────────────────────────────────────────────────────
  # Stat Card
  # ────────────────────────────────────────────────────────

  @doc """
  Renders a dashboard stat card with icon, value, label, and optional change indicator.

  ## Examples

      <.stat_card label="Total Members" value={150} icon="hero-users" color="primary" change="+12%" />
  """
  attr :label, :string, required: true
  attr :value, :any, required: true, doc: "display value (string or number)"
  attr :icon, :string, required: true, doc: "heroicon name"
  attr :color, :string, default: "primary", values: ~w(primary secondary accent success warning error info)
  attr :change, :string, default: nil, doc: "change indicator like '+12%' or '-5%'"

  def stat_card(assigns) do
    bg_class = %{
      "primary" => "bg-primary/10 text-primary",
      "secondary" => "bg-secondary/10 text-secondary",
      "accent" => "bg-accent/10 text-accent",
      "success" => "bg-success/10 text-success",
      "warning" => "bg-warning/10 text-warning",
      "error" => "bg-error/10 text-error",
      "info" => "bg-info/10 text-info"
    }

    assigns = assign(assigns, :icon_bg, Map.get(bg_class, assigns.color, "bg-primary/10 text-primary"))

    ~H"""
    <div class="bg-base-100 rounded-2xl border border-base-300/50 p-5 shadow-sm hover:shadow-md transition-shadow">
      <div class="flex items-center justify-between mb-3">
        <div class={["w-10 h-10 rounded-xl flex items-center justify-center", @icon_bg]}>
          <.icon name={@icon} class="size-5" />
        </div>
        <span
          :if={@change}
          class={[
            "text-xs font-semibold px-2 py-0.5 rounded-full",
            String.starts_with?(@change || "", "+") && "bg-success/10 text-success",
            String.starts_with?(@change || "", "-") && "bg-error/10 text-error"
          ]}
        >
          {@change}
        </span>
      </div>
      <p class="text-2xl font-bold">{@value}</p>
      <p class="text-sm text-base-content/60 mt-0.5">{@label}</p>
    </div>
    """
  end

  # ────────────────────────────────────────────────────────
  # Card
  # ────────────────────────────────────────────────────────

  @doc """
  Renders a content card container.

  ## Examples

      <.card title="Recent Activity">
        <p>Some content here</p>
      </.card>

      <.card title="Members" subtitle="Active members in your gym">
        <:header_actions>
          <.button variant="ghost" size="sm">View All</.button>
        </:header_actions>
        <p>Content</p>
      </.card>
  """
  attr :title, :string, default: nil
  attr :subtitle, :string, default: nil
  attr :padded, :boolean, default: true, doc: "apply padding to card body"
  attr :class, :any, default: nil
  attr :id, :string, default: nil

  slot :header_actions
  slot :inner_block, required: true

  def card(assigns) do
    ~H"""
    <div id={@id} class={["bg-base-100 rounded-2xl border border-base-300/50 shadow-sm overflow-hidden", @class]}>
      <div :if={@title} class="flex items-center justify-between px-5 py-4 border-b border-base-300/50">
        <div>
          <h3 class="text-base font-semibold">{@title}</h3>
          <p :if={@subtitle} class="text-xs text-base-content/50 mt-0.5">{@subtitle}</p>
        </div>
        <div :if={@header_actions != []}>
          {render_slot(@header_actions)}
        </div>
      </div>
      <div class={@padded && "p-5"}>
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  # ────────────────────────────────────────────────────────
  # Tab Group
  # ────────────────────────────────────────────────────────

  @doc """
  Renders a tab navigation group.

  ## Examples

      <.tab_group active={@active_tab} on_tab_change="change_tab">
        <:tab id="overview" label="Overview">
          <p>Overview content</p>
        </:tab>
        <:tab id="members" label="Members">
          <p>Members content</p>
        </:tab>
      </.tab_group>
  """
  attr :active, :string, required: true, doc: "the id of the active tab"
  attr :on_tab_change, :string, default: "change_tab", doc: "phx-click event name"

  slot :tab, required: true do
    attr :id, :string, required: true
    attr :label, :string, required: true
    attr :icon, :string
  end

  def tab_group(assigns) do
    ~H"""
    <div>
      <div class="flex gap-1 border-b border-base-300/50 mb-6 overflow-x-auto">
        <button
          :for={tab <- @tab}
          phx-click={@on_tab_change}
          phx-value-tab={tab.id}
          class={[
            "px-4 py-2.5 text-sm font-medium border-b-2 transition-colors whitespace-nowrap cursor-pointer",
            tab.id == @active && "border-primary text-primary",
            tab.id != @active && "border-transparent text-base-content/60 hover:text-base-content hover:border-base-300"
          ]}
        >
          <.icon :if={tab[:icon]} name={tab[:icon]} class="size-4 mr-1.5 inline-block" />
          {tab.label}
        </button>
      </div>
      <div :for={tab <- @tab} :if={tab.id == @active}>
        {render_slot(tab)}
      </div>
    </div>
    """
  end

  # ────────────────────────────────────────────────────────
  # Section
  # ────────────────────────────────────────────────────────

  @doc """
  Renders a page content section with consistent spacing.

  ## Examples

      <.section title="Recent Members" subtitle="Last 7 days">
        <p>Content</p>
      </.section>
  """
  attr :title, :string, default: nil
  attr :subtitle, :string, default: nil

  slot :actions
  slot :inner_block, required: true

  def section(assigns) do
    ~H"""
    <div class="mb-8">
      <div :if={@title} class="flex items-center justify-between mb-4">
        <div>
          <h2 class="text-lg font-semibold">{@title}</h2>
          <p :if={@subtitle} class="text-sm text-base-content/50 mt-0.5">{@subtitle}</p>
        </div>
        <div :if={@actions != []}>
          {render_slot(@actions)}
        </div>
      </div>
      {render_slot(@inner_block)}
    </div>
    """
  end

  # ────────────────────────────────────────────────────────
  # Wizard
  # ────────────────────────────────────────────────────────

  @doc """
  Renders a multi-step form wizard.

  ## Examples

      <.wizard
        current_step={@step}
        steps={[%{id: "details", label: "Details"}, %{id: "location", label: "Location"}, %{id: "plans", label: "Plans"}]}
      >
        <:step_content>
          <div :if={@step == "details"}>Step 1 form</div>
          <div :if={@step == "location"}>Step 2 form</div>
          <div :if={@step == "plans"}>Step 3 form</div>
        </:step_content>
        <:actions>
          <.button variant="ghost" phx-click="wizard_back">Back</.button>
          <.button phx-click="wizard_next">Next</.button>
        </:actions>
      </.wizard>
  """
  attr :current_step, :string, required: true
  attr :steps, :list, required: true, doc: "list of %{id: string, label: string}"

  slot :step_content, required: true
  slot :actions

  def wizard(assigns) do
    current_index =
      Enum.find_index(assigns.steps, fn s -> s.id == assigns.current_step end) || 0

    assigns = assign(assigns, :current_index, current_index)

    ~H"""
    <div>
      <%!-- Step indicator --%>
      <div class="flex items-center justify-center mb-8">
        <ol class="flex items-center gap-2">
          <%= for {step, idx} <- Enum.with_index(@steps) do %>
            <li class="flex items-center gap-2">
              <div class={[
                "w-8 h-8 rounded-full flex items-center justify-center text-sm font-semibold transition-colors",
                idx < @current_index && "bg-primary text-primary-content",
                idx == @current_index && "bg-primary text-primary-content ring-4 ring-primary/20",
                idx > @current_index && "bg-base-300 text-base-content/40"
              ]}>
                <.icon :if={idx < @current_index} name="hero-check-mini" class="size-4" />
                <span :if={idx >= @current_index}>{idx + 1}</span>
              </div>
              <span class={[
                "text-sm font-medium hidden sm:inline",
                idx == @current_index && "text-base-content",
                idx != @current_index && "text-base-content/50"
              ]}>
                {step.label}
              </span>
              <div :if={idx < length(@steps) - 1} class="w-8 sm:w-12 h-px bg-base-300 mx-1"></div>
            </li>
          <% end %>
        </ol>
      </div>

      <%!-- Step content --%>
      <div class="mb-6">
        {render_slot(@step_content)}
      </div>

      <%!-- Actions --%>
      <div :if={@actions != []} class="flex items-center justify-between pt-4 border-t border-base-300/50">
        {render_slot(@actions)}
      </div>
    </div>
    """
  end

  # ────────────────────────────────────────────────────────
  # Command Palette
  # ────────────────────────────────────────────────────────

  @doc """
  Renders a Cmd+K command palette for quick navigation.

  ## Examples

      <.command_palette
        id="cmd-palette"
        items={[
          %{label: "Dashboard", path: "/dashboard", icon: "hero-squares-2x2-solid"},
          %{label: "Members", path: "/gym/members", icon: "hero-user-group-solid"}
        ]}
      />
  """
  attr :id, :string, default: "command-palette"
  attr :items, :list, default: [], doc: "list of %{label: string, path: string, icon: string}"

  def command_palette(assigns) do
    ~H"""
    <div
      id={@id}
      class="hidden"
      phx-hook="CommandPalette"
      data-items={Jason.encode!(@items)}
    >
      <div class="command-palette-backdrop" phx-click={JS.hide(to: "##{@id}")}></div>
      <div class="command-palette">
        <div class="bg-base-100 rounded-2xl shadow-2xl border border-base-300/50 overflow-hidden">
          <div class="p-3 border-b border-base-300/50">
            <div class="relative">
              <.icon name="hero-magnifying-glass" class="size-5 absolute left-3 top-1/2 -translate-y-1/2 text-base-content/40" />
              <input
                type="text"
                placeholder="Search pages..."
                class="w-full input input-sm pl-10 bg-transparent border-none focus:outline-none"
                id={"#{@id}-search"}
                autocomplete="off"
              />
            </div>
          </div>
          <div class="max-h-72 overflow-y-auto p-2" id={"#{@id}-results"}>
            <a
              :for={item <- @items}
              href={item.path}
              class="flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm hover:bg-base-200 transition-colors command-palette-item"
              data-label={String.downcase(item.label)}
            >
              <.icon :if={item[:icon]} name={item.icon} class="size-5 text-base-content/50" />
              <span>{item.label}</span>
            </a>
          </div>
          <div class="p-2 border-t border-base-300/50 flex items-center gap-4 text-xs text-base-content/40 px-4">
            <span><kbd class="kbd kbd-xs">Esc</kbd> to close</span>
            <span><kbd class="kbd kbd-xs">Enter</kbd> to select</span>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
