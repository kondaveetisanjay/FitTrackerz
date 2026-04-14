defmodule FitTrackerzWeb.DataComponents do
  @moduledoc """
  Data display components — adaptive tables, filters, pagination,
  empty states, and detail grids.
  """
  use Phoenix.Component

  import FitTrackerzWeb.CoreComponents

  # ────────────────────────────────────────────────────────
  # Data Table (Adaptive: table on desktop, cards on mobile)
  # ────────────────────────────────────────────────────────

  @doc """
  Renders an adaptive data table — full table on desktop, card list on mobile.

  ## Examples

      <.data_table id="members" rows={@members}>
        <:col :let={member} label="Name" sort="name">{member.name}</:col>
        <:col :let={member} label="Plan">{member.plan}</:col>
        <:col :let={member} label="Status">
          <.badge variant="success">{member.status}</.badge>
        </:col>
        <:mobile_card :let={member}>
          <div class="flex items-center gap-3">
            <.avatar name={member.name} size="sm" />
            <div>
              <p class="font-semibold">{member.name}</p>
              <p class="text-xs text-base-content/50">{member.plan}</p>
            </div>
          </div>
        </:mobile_card>
        <:actions :let={member}>
          <button phx-click="edit" phx-value-id={member.id}>Edit</button>
        </:actions>
      </.data_table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil
  attr :sort_by, :string, default: nil, doc: "current sort column"
  attr :sort_dir, :string, default: "asc", doc: "asc or desc"
  attr :on_sort, :string, default: nil, doc: "phx-click event for sorting"

  attr :row_item, :any,
    default: &Function.identity/1

  slot :col do
    attr :label, :string
    attr :sort, :string, doc: "sort key for this column"
    attr :class, :string
  end

  slot :mobile_card, doc: "mobile card layout for each row"

  slot :actions, doc: "action buttons for each row"

  def data_table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div>
      <%!-- Desktop table --%>
      <div class="hidden lg:block overflow-x-auto">
        <table class="table w-full">
          <thead>
            <tr class="border-b border-base-300/50">
              <th
                :for={col <- @col}
                class={["text-xs font-semibold text-base-content/50 uppercase tracking-wider", col[:class]]}
              >
                <button
                  :if={col[:sort] && @on_sort}
                  phx-click={@on_sort}
                  phx-value-sort={col[:sort]}
                  class="flex items-center gap-1 cursor-pointer hover:text-base-content"
                >
                  {col[:label]}
                  <.icon
                    :if={@sort_by == col[:sort]}
                    name={if @sort_dir == "asc", do: "hero-chevron-up-mini", else: "hero-chevron-down-mini"}
                    class="size-3"
                  />
                </button>
                <span :if={!col[:sort] || !@on_sort}>{col[:label]}</span>
              </th>
              <th :if={@actions != []} class="text-right text-xs font-semibold text-base-content/50 uppercase tracking-wider">
                Actions
              </th>
            </tr>
          </thead>
          <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}>
            <tr
              :for={row <- @rows}
              id={@row_id && @row_id.(row)}
              class="border-b border-base-300/30 hover:bg-base-200/50 transition-colors"
            >
              <td :for={col <- @col} class={["py-3.5", col[:class]]}>
                {render_slot(col, @row_item.(row))}
              </td>
              <td :if={@actions != []} class="py-3.5 text-right">
                <div class="flex items-center justify-end gap-2">
                  {render_slot(@actions, @row_item.(row))}
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <%!-- Mobile card list --%>
      <div class="lg:hidden space-y-3" id={"#{@id}-mobile"}>
        <div
          :for={row <- @rows}
          id={@row_id && "#{@row_id.(row)}-mobile"}
          class="bg-base-100 rounded-xl border border-base-300/50 p-4"
        >
          <div :if={@mobile_card != []} class="flex items-center justify-between">
            <div class="flex-1 min-w-0">
              {render_slot(@mobile_card, @row_item.(row))}
            </div>
            <div :if={@actions != []} class="ml-3 shrink-0">
              {render_slot(@actions, @row_item.(row))}
            </div>
          </div>
          <%!-- Fallback: render cols as key-value pairs if no mobile_card slot --%>
          <div :if={@mobile_card == []} class="space-y-2">
            <div :for={col <- @col} class="flex items-center justify-between">
              <span class="text-xs text-base-content/50">{col[:label]}</span>
              <span class="text-sm">{render_slot(col, @row_item.(row))}</span>
            </div>
            <div :if={@actions != []} class="pt-2 border-t border-base-300/30 flex justify-end gap-2">
              {render_slot(@actions, @row_item.(row))}
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ────────────────────────────────────────────────────────
  # Filter Bar
  # ────────────────────────────────────────────────────────

  @doc """
  Renders a search and filter bar above data tables.

  ## Examples

      <.filter_bar search_placeholder="Search members..." on_search="search">
        <:filter>
          <.input type="select" name="status" options={["All", "Active", "Expired"]} />
        </:filter>
      </.filter_bar>
  """
  attr :search_placeholder, :string, default: "Search..."
  attr :search_value, :string, default: ""
  attr :on_search, :string, default: "search", doc: "phx-change event for search"

  slot :filter, doc: "filter dropdowns or inputs"

  def filter_bar(assigns) do
    ~H"""
    <div class="flex flex-col sm:flex-row items-stretch sm:items-center gap-3 mb-4">
      <div class="relative flex-1">
        <.icon name="hero-magnifying-glass" class="size-4 absolute left-3 top-1/2 -translate-y-1/2 text-base-content/40" />
        <input
          type="search"
          placeholder={@search_placeholder}
          value={@search_value}
          phx-change={@on_search}
          phx-debounce="300"
          name="search"
          class="w-full input input-sm pl-10"
        />
      </div>
      <div :if={@filter != []} class="flex items-center gap-2 shrink-0">
        {render_slot(@filter)}
      </div>
    </div>
    """
  end

  # ────────────────────────────────────────────────────────
  # Pagination
  # ────────────────────────────────────────────────────────

  @doc """
  Renders page navigation controls.

  ## Examples

      <.pagination current_page={1} total_pages={10} on_page_change="page_change" />
  """
  attr :current_page, :integer, required: true
  attr :total_pages, :integer, required: true
  attr :on_page_change, :string, default: "page_change"

  def pagination(assigns) do
    # Calculate visible page range (show max 5 pages around current)
    range_start = max(1, assigns.current_page - 2)
    range_end = min(assigns.total_pages, assigns.current_page + 2)
    pages = Enum.to_list(range_start..range_end)

    assigns = assign(assigns, :pages, pages)

    ~H"""
    <div :if={@total_pages > 1} class="flex items-center justify-center gap-1 mt-6">
      <button
        phx-click={@on_page_change}
        phx-value-page={@current_page - 1}
        disabled={@current_page <= 1}
        class="btn btn-ghost btn-sm btn-circle"
      >
        <.icon name="hero-chevron-left-mini" class="size-4" />
      </button>

      <button
        :if={List.first(@pages) > 1}
        phx-click={@on_page_change}
        phx-value-page="1"
        class="btn btn-ghost btn-sm btn-circle"
      >
        1
      </button>
      <span :if={List.first(@pages) > 2} class="text-base-content/30 px-1">...</span>

      <button
        :for={page <- @pages}
        phx-click={@on_page_change}
        phx-value-page={page}
        class={[
          "btn btn-sm btn-circle",
          page == @current_page && "btn-primary",
          page != @current_page && "btn-ghost"
        ]}
      >
        {page}
      </button>

      <span :if={List.last(@pages) < @total_pages - 1} class="text-base-content/30 px-1">...</span>
      <button
        :if={List.last(@pages) < @total_pages}
        phx-click={@on_page_change}
        phx-value-page={@total_pages}
        class="btn btn-ghost btn-sm btn-circle"
      >
        {@total_pages}
      </button>

      <button
        phx-click={@on_page_change}
        phx-value-page={@current_page + 1}
        disabled={@current_page >= @total_pages}
        class="btn btn-ghost btn-sm btn-circle"
      >
        <.icon name="hero-chevron-right-mini" class="size-4" />
      </button>
    </div>
    """
  end

  # ────────────────────────────────────────────────────────
  # Empty State
  # ────────────────────────────────────────────────────────

  @doc """
  Renders an empty state placeholder with icon, message, and optional action.

  ## Examples

      <.empty_state icon="hero-user-group" title="No members yet" subtitle="Invite your first member">
        <:action>
          <.button icon="hero-plus">Invite Member</.button>
        </:action>
      </.empty_state>
  """
  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil

  slot :action

  def empty_state(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center py-16 px-4 text-center">
      <div class="w-16 h-16 rounded-2xl bg-base-200 flex items-center justify-center mb-4">
        <.icon name={@icon} class="size-8 text-base-content/30" />
      </div>
      <p class="text-base font-semibold text-base-content/70">{@title}</p>
      <p :if={@subtitle} class="text-sm text-base-content/50 mt-1 max-w-sm">{@subtitle}</p>
      <div :if={@action != []} class="mt-5">
        {render_slot(@action)}
      </div>
    </div>
    """
  end

  # ────────────────────────────────────────────────────────
  # Detail Grid
  # ────────────────────────────────────────────────────────

  @doc """
  Renders a 2-column key-value grid for detail pages.

  ## Examples

      <.detail_grid>
        <:item label="Name">{@gym.name}</:item>
        <:item label="Status"><.badge variant="success">Active</.badge></:item>
        <:item label="Members">{@member_count}</:item>
      </.detail_grid>
  """
  slot :item, required: true do
    attr :label, :string, required: true
  end

  def detail_grid(assigns) do
    ~H"""
    <dl class="grid grid-cols-1 sm:grid-cols-2 gap-x-6 gap-y-4">
      <div :for={item <- @item} class="flex flex-col gap-1">
        <dt class="text-xs font-semibold text-base-content/50 uppercase tracking-wider">{item.label}</dt>
        <dd class="text-sm">{render_slot(item)}</dd>
      </div>
    </dl>
    """
  end

  # ────────────────────────────────────────────────────────
  # List Item
  # ────────────────────────────────────────────────────────

  @doc """
  Renders a simple key-value list row.

  ## Examples

      <.list_item label="Email">{@user.email}</.list_item>
  """
  attr :label, :string, required: true

  slot :inner_block, required: true

  def list_item(assigns) do
    ~H"""
    <div class="flex items-center justify-between py-3 border-b border-base-300/30 last:border-0">
      <span class="text-sm text-base-content/60">{@label}</span>
      <span class="text-sm font-medium">{render_slot(@inner_block)}</span>
    </div>
    """
  end
end
