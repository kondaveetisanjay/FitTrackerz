defmodule FitTrackerzWeb.CoreComponents do
  @moduledoc """
  Provides core UI components built on Tailwind CSS and daisyUI.

  Design system reference:
    * [daisyUI](https://daisyui.com/docs/intro/)
    * [Tailwind CSS](https://tailwindcss.com)
    * [Heroicons](https://heroicons.com) - see `icon/1`
  """
  use Phoenix.Component
  use Gettext, backend: FitTrackerzWeb.Gettext

  alias Phoenix.LiveView.JS

  ## Flash

  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class="toast toast-top toast-end z-50"
      {@rest}
    >
      <div class={[
        "alert w-80 sm:w-96 max-w-80 sm:max-w-96 text-wrap shadow-lg rounded-xl",
        @kind == :info && "alert-info",
        @kind == :error && "alert-error"
      ]}>
        <.icon :if={@kind == :info} name="hero-information-circle" class="size-5 shrink-0" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle" class="size-5 shrink-0" />
        <div>
          <p :if={@title} class="font-semibold">{@title}</p>
          <p>{msg}</p>
        </div>
        <div class="flex-1" />
        <button type="button" class="group self-start cursor-pointer" aria-label={gettext("close")}>
          <.icon name="hero-x-mark" class="size-5 opacity-40 group-hover:opacity-70" />
        </button>
      </div>
    </div>
    """
  end

  ## Button

  attr :rest, :global, include: ~w(href navigate patch method download name value disabled type form)
  attr :class, :any, default: nil
  attr :variant, :string, default: nil
  attr :size, :string, values: ~w(xs sm md lg), default: "md"
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    variant_classes = %{
      "primary" => "btn-primary shadow-md shadow-primary/20 hover:shadow-primary/30",
      "secondary" => "btn-secondary shadow-md shadow-secondary/20",
      "ghost" => "btn-ghost",
      "outline" => "btn-outline",
      "danger" => "btn-error shadow-md shadow-error/20",
      nil => "btn-primary btn-soft"
    }

    size_classes = %{
      "xs" => "btn-xs",
      "sm" => "btn-sm",
      "md" => "",
      "lg" => "btn-lg"
    }

    assigns =
      assigns
      |> assign_new(:computed_class, fn ->
        [
          "btn press-scale font-semibold",
          Map.fetch!(variant_classes, assigns.variant),
          Map.fetch!(size_classes, assigns.size),
          assigns.class
        ]
      end)

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@computed_class} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={@computed_class} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  ## Input

  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any
  attr :hint, :string, default: nil

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select tel text textarea time url week hidden)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :any, default: nil, doc: "the input class to use over defaults"
  attr :error_class, :any, default: nil, doc: "the input error class to use over defaults"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "hidden"} = assigns) do
    ~H"""
    <input type="hidden" id={@id} name={@name} value={@value} {@rest} />
    """
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class="fieldset mb-3">
      <label class="flex items-center gap-3 cursor-pointer">
        <input
          type="hidden"
          name={@name}
          value="false"
          disabled={@rest[:disabled]}
          form={@rest[:form]}
        />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class={@class || "checkbox checkbox-sm checkbox-primary"}
          {@rest}
        />
        <span class="label text-sm font-medium">{@label}</span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="fieldset mb-3">
      <label>
        <span :if={@label} class="label mb-1.5 text-sm font-semibold">{@label}</span>
        <select
          id={@id}
          name={@name}
          class={[@class || "w-full select select-bordered focus:select-primary focus:ring-2 focus:ring-primary/10 transition-all", @errors != [] && (@error_class || "select-error")]}
          multiple={@multiple}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          {Phoenix.HTML.Form.options_for_select(@options, @value)}
        </select>
      </label>
      <p :if={@hint} class="text-xs text-base-content/40 mt-1.5">{@hint}</p>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="fieldset mb-3">
      <label>
        <span :if={@label} class="label mb-1.5 text-sm font-semibold">{@label}</span>
        <textarea
          id={@id}
          name={@name}
          class={[
            @class || "w-full textarea textarea-bordered focus:textarea-primary focus:ring-2 focus:ring-primary/10 transition-all",
            @errors != [] && (@error_class || "textarea-error")
          ]}
          {@rest}
        >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      </label>
      <p :if={@hint} class="text-xs text-base-content/40 mt-1.5">{@hint}</p>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(assigns) do
    ~H"""
    <div class="fieldset mb-3">
      <label>
        <span :if={@label} class="label mb-1.5 text-sm font-semibold">{@label}</span>
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class={[
            @class || "w-full input input-bordered focus:input-primary focus:ring-2 focus:ring-primary/10 transition-all",
            @errors != [] && (@error_class || "input-error")
          ]}
          {@rest}
        />
      </label>
      <p :if={@hint} class="text-xs text-base-content/40 mt-1.5">{@hint}</p>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  defp error(assigns) do
    ~H"""
    <p class="mt-1.5 flex gap-2 items-center text-sm text-error animate-slide-down">
      <.icon name="hero-exclamation-circle" class="size-4 shrink-0" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  ## Page Header

  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  attr :back, :string, default: nil, doc: "the back navigation path"
  slot :actions

  def page_header(assigns) do
    ~H"""
    <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-6">
      <div class="flex items-start gap-3">
        <.link :if={@back} navigate={@back} class="btn btn-ghost btn-sm btn-circle hover:bg-primary/10 mt-0.5 shrink-0">
          <.icon name="hero-arrow-left" class="size-5" />
        </.link>
        <div>
          <h1 class="text-2xl sm:text-3xl font-brand tracking-tight">{@title}</h1>
          <p :if={@subtitle} class="text-base-content/50 mt-1 text-sm">{@subtitle}</p>
        </div>
      </div>
      <div :if={@actions != []} class="flex items-center gap-2 sm:shrink-0">
        {render_slot(@actions)}
      </div>
    </div>
    """
  end

  ## Header (legacy)

  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex items-center justify-between gap-6", "pb-4"]}>
      <div>
        <h1 class="text-lg font-semibold leading-8">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="text-sm text-base-content/70">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  ## Table

  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class="ft-table overflow-x-auto">
      <table class="w-full">
        <thead>
          <tr>
            <th :for={col <- @col} class="text-[11px] font-bold text-base-content/40 uppercase tracking-widest py-3 px-4 text-left whitespace-nowrap">
              {col[:label]}
            </th>
            <th :if={@action != []} class="text-[11px] font-bold text-base-content/40 uppercase tracking-widest py-3 px-4 text-right">
              <span class="sr-only">{gettext("Actions")}</span>
            </th>
          </tr>
        </thead>
        <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}>
          <tr
            :for={row <- @rows}
            id={@row_id && @row_id.(row)}
            class="border-t border-base-200/60 hover:bg-base-200/20 transition-colors"
          >
            <td
              :for={col <- @col}
              phx-click={@row_click && @row_click.(row)}
              class={["py-3 px-4 text-sm", @row_click && "hover:cursor-pointer"]}
            >
              {render_slot(col, @row_item.(row))}
            </td>
            <td :if={@action != []} class="py-3 px-4 text-right">
              <div class="flex items-center justify-end gap-2">
                <%= for action <- @action do %>
                  {render_slot(action, @row_item.(row))}
                <% end %>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  ## Data List

  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <ul class="list">
      <li :for={item <- @item} class="list-row">
        <div class="list-col-grow">
          <div class="font-bold">{item.title}</div>
          <div>{render_slot(item)}</div>
        </div>
      </li>
    </ul>
    """
  end

  ## Status Badge

  attr :status, :atom, required: true
  attr :class, :string, default: nil

  @status_map %{
    active: {"Active", "badge-success"},
    verified: {"Verified", "badge-success"},
    confirmed: {"Confirmed", "badge-info"},
    pending: {"Pending", "badge-warning"},
    pending_verification: {"Pending", "badge-warning"},
    upcoming: {"Upcoming", "badge-info"},
    scheduled: {"Scheduled", "badge-info"},
    inactive: {"Inactive", "badge-ghost"},
    cancelled: {"Cancelled", "badge-error"},
    declined: {"Declined", "badge-error"},
    rejected: {"Rejected", "badge-error"},
    suspended: {"Suspended", "badge-error"},
    expired: {"Expired", "badge-ghost"},
    completed: {"Completed", "badge-success"},
    paid: {"Paid", "badge-success"},
    failed: {"Failed", "badge-error"},
    refunded: {"Refunded", "badge-warning"}
  }

  def status_badge(assigns) do
    {label, badge_class} = Map.get(@status_map, assigns.status, {Phoenix.Naming.humanize(assigns.status), "badge-ghost"})
    assigns = assign(assigns, label: label, badge_class: badge_class)

    ~H"""
    <span class={["badge badge-sm font-semibold", @badge_class, @class]}>{@label}</span>
    """
  end

  ## Stat Card

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :icon, :string, required: true
  attr :color, :string, default: "primary"
  attr :subtitle, :string, default: nil
  attr :href, :string, default: nil
  attr :id, :string, default: nil
  attr :class, :string, default: nil

  def stat_card(assigns) do
    ~H"""
    <%= if @href do %>
      <.link navigate={@href} class={["ft-card ft-card-hover group cursor-pointer", @class]} id={@id}>
        <.stat_card_inner {assigns} />
      </.link>
    <% else %>
      <div class={["ft-card group", @class]} id={@id}>
        <.stat_card_inner {assigns} />
      </div>
    <% end %>
    """
  end

  defp stat_card_inner(assigns) do
    ~H"""
    <div class={[
      "p-5 border-l-4 rounded-l-none",
      color_class(@color, "border")
    ]}>
      <div class="flex items-center justify-between">
        <div>
          <p class="text-[11px] font-bold text-base-content/35 uppercase tracking-widest">
            {@label}
          </p>
          <p class="text-3xl font-black mt-1.5 tracking-tight tabular-nums">{@value}</p>
        </div>
        <div class={[
          "w-14 h-14 rounded-2xl flex items-center justify-center transition-all duration-300 group-hover:scale-110",
          color_class(@color, "bg-gradient")
        ]}>
          <.icon name={@icon} class={["size-6", color_class(@color, "text")]} />
        </div>
      </div>
      <p :if={@subtitle} class="text-xs text-base-content/40 mt-2.5 font-medium">{@subtitle}</p>
    </div>
    """
  end

  ## Section Header

  attr :title, :string, required: true
  attr :icon, :string, default: nil
  attr :icon_color, :string, default: "primary"
  slot :actions

  def section_header(assigns) do
    ~H"""
    <div class="mb-4">
      <div class="flex items-center justify-between">
        <h2 class="text-lg font-bold tracking-tight flex items-center gap-2.5">
          <div
            :if={@icon}
            class={["w-9 h-9 rounded-xl flex items-center justify-center", color_class(@icon_color, "bg")]}
          >
            <.icon name={@icon} class={["size-4.5", color_class(@icon_color, "text")]} />
          </div>
          {@title}
        </h2>
        <div :if={@actions != []} class="flex items-center gap-2">
          {render_slot(@actions)}
        </div>
      </div>
      <div class="h-px bg-gradient-to-r from-base-300/60 to-transparent mt-3"></div>
    </div>
    """
  end

  ## Empty State

  attr :icon, :string, required: true
  attr :color, :string, default: "primary"
  attr :title, :string, required: true
  attr :message, :string, required: true
  slot :actions

  def empty_state(assigns) do
    ~H"""
    <div class="py-12 px-8 rounded-2xl bg-base-200/30 text-center">
      <div class={[
        "w-20 h-20 rounded-3xl flex items-center justify-center mx-auto ring-4",
        color_class(@color, "bg-gradient"),
        color_class(@color, "ring")
      ]}>
        <.icon name={@icon} class={["size-9", color_class(@color, "text")]} />
      </div>
      <p class="text-base font-bold mt-5">{@title}</p>
      <p class="text-sm text-base-content/50 mt-2 max-w-sm mx-auto leading-relaxed">{@message}</p>
      <div :if={@actions != []} class="mt-6">
        {render_slot(@actions)}
      </div>
    </div>
    """
  end

  ## Icon

  attr :name, :string, required: true
  attr :class, :any, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  ## Brand Logo

  attr :class, :string, default: "h-8 w-auto"

  def brand_logo(assigns) do
    ~H"""
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 320 50" class={@class} role="img" aria-label="FitTrackerz">
      <text
        x="0"
        y="40"
        font-family="'Gilroy', 'Impact', 'Arial Narrow', sans-serif"
        font-weight="700"
        font-size="44"
        letter-spacing="1.5"
      >
        <tspan style="fill: var(--color-primary)">Fit</tspan><tspan style="fill: currentColor">Trackerz</tspan>
      </text>
      <rect x="0" y="46" width="95" height="3.5" rx="1.75" style="fill: var(--color-secondary)" />
    </svg>
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  ## Color Helpers

  defp color_class(color, type) do
    case {color, type} do
      # Border left accent
      {c, "border"} -> "border-#{c}/30"

      # Background tint
      {"primary", "bg"} -> "bg-primary/10"
      {"secondary", "bg"} -> "bg-secondary/10"
      {"info", "bg"} -> "bg-info/10"
      {"success", "bg"} -> "bg-success/10"
      {"warning", "bg"} -> "bg-warning/10"
      {"accent", "bg"} -> "bg-accent/10"
      {"error", "bg"} -> "bg-error/10"

      # Gradient background for icons
      {"primary", "bg-gradient"} -> "bg-gradient-to-br from-primary/15 to-primary/5"
      {"secondary", "bg-gradient"} -> "bg-gradient-to-br from-secondary/15 to-secondary/5"
      {"info", "bg-gradient"} -> "bg-gradient-to-br from-info/15 to-info/5"
      {"success", "bg-gradient"} -> "bg-gradient-to-br from-success/15 to-success/5"
      {"warning", "bg-gradient"} -> "bg-gradient-to-br from-warning/15 to-warning/5"
      {"accent", "bg-gradient"} -> "bg-gradient-to-br from-accent/15 to-accent/5"
      {"error", "bg-gradient"} -> "bg-gradient-to-br from-error/15 to-error/5"

      # Text color
      {"primary", "text"} -> "text-primary"
      {"secondary", "text"} -> "text-secondary"
      {"info", "text"} -> "text-info"
      {"success", "text"} -> "text-success"
      {"warning", "text"} -> "text-warning"
      {"accent", "text"} -> "text-accent"
      {"error", "text"} -> "text-error"

      # Ring color (for empty state)
      {c, "ring"} -> "ring-#{c}/5"

      _ -> ""
    end
  end

  ## Translation Helpers

  def translate_error({msg, opts}) do
    if count = opts[:count] do
      Gettext.dngettext(FitTrackerzWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(FitTrackerzWeb.Gettext, "errors", msg, opts)
    end
  end

  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
