defmodule FitTrackerzWeb.CoreComponents do
  @moduledoc """
  Core UI components — base primitives for the FitTrackerz design system.

  Provides button, input, icon, modal, flash, badge, avatar, dropdown, and tooltip.
  All components use daisyUI classes internally and expose semantic props.
  """
  use Phoenix.Component
  use Gettext, backend: FitTrackerzWeb.Gettext

  alias Phoenix.LiveView.JS

  # ────────────────────────────────────────────────────────
  # Flash
  # ────────────────────────────────────────────────────────

  @doc """
  Renders flash notices as toast notifications.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:success} flash={@flash} />
      <.flash kind={:error} phx-mounted={show("#flash")}>Something failed</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error, :success, :warning], doc: "used for styling and flash lookup"
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
        "alert w-80 sm:w-96 max-w-80 sm:max-w-96 text-wrap shadow-lg",
        @kind == :info && "alert-info",
        @kind == :error && "alert-error",
        @kind == :success && "alert-success",
        @kind == :warning && "alert-warning"
      ]}>
        <.icon :if={@kind == :info} name="hero-information-circle" class="size-5 shrink-0" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle" class="size-5 shrink-0" />
        <.icon :if={@kind == :success} name="hero-check-circle" class="size-5 shrink-0" />
        <.icon :if={@kind == :warning} name="hero-exclamation-triangle" class="size-5 shrink-0" />
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

  # ────────────────────────────────────────────────────────
  # Button
  # ────────────────────────────────────────────────────────

  @doc """
  Renders a button with variant, size, icon, and loading support.

  ## Examples

      <.button>Default</.button>
      <.button variant="primary" icon="hero-plus">Add Member</.button>
      <.button variant="ghost" size="sm">Cancel</.button>
      <.button variant="danger" loading={true}>Deleting...</.button>
      <.button navigate={~p"/"}>Home</.button>
  """
  attr :variant, :string,
    default: "primary",
    values: ~w(primary secondary ghost danger outline)

  attr :size, :string, default: "md", values: ~w(sm md lg)
  attr :icon, :string, default: nil, doc: "heroicon name to show before label"
  attr :loading, :boolean, default: false, doc: "show loading spinner"
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(href navigate patch method download name value disabled type form)

  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    variant_classes = %{
      "primary" => "btn-primary",
      "secondary" => "btn-secondary",
      "ghost" => "btn-ghost",
      "danger" => "btn-error",
      "outline" => "btn-outline btn-primary"
    }

    size_classes = %{
      "sm" => "btn-sm",
      "md" => "",
      "lg" => "btn-lg"
    }

    assigns =
      assign(assigns, :computed_class, [
        "btn rounded-xl",
        Map.get(variant_classes, assigns.variant, "btn-primary"),
        Map.get(size_classes, assigns.size, ""),
        assigns.loading && "btn-disabled",
        assigns.class
      ])

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@computed_class} {@rest}>
        <span :if={@loading} class="loading loading-spinner loading-xs"></span>
        <.icon :if={@icon && !@loading} name={@icon} class={icon_size(@size)} />
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={@computed_class} disabled={@loading || @rest[:disabled]} {@rest}>
        <span :if={@loading} class="loading loading-spinner loading-xs"></span>
        <.icon :if={@icon && !@loading} name={@icon} class={icon_size(@size)} />
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  defp icon_size("sm"), do: "size-3.5"
  defp icon_size("lg"), do: "size-5"
  defp icon_size(_), do: "size-4"

  # ────────────────────────────────────────────────────────
  # Input
  # ────────────────────────────────────────────────────────

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Examples

      <.input field={@form[:email]} type="email" />
      <.input name="my-input" errors={["oh no!"]} />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any, default: nil
  attr :icon, :string, default: nil, doc: "heroicon name for input prefix"

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

    # Force-assign value (not assign_new) so HEEx change tracking re-renders
    # the value attribute on every form re-render. Without this, when other
    # fields trigger validate/re-render, untouched fields lose their `value=`
    # attribute and the browser ends up submitting empty strings.
    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign(:value, Map.get(assigns, :value) || field.value)
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
    <div class="fieldset mb-2">
      <label>
        <input
          type="hidden"
          name={@name}
          value="false"
          disabled={@rest[:disabled]}
          form={@rest[:form]}
        />
        <span class="label">
          <input
            type="checkbox"
            id={@id}
            name={@name}
            value="true"
            checked={@checked}
            class={@class || "checkbox checkbox-sm checkbox-primary"}
            {@rest}
          />{@label}
        </span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label>
        <span :if={@label} class="label mb-1 text-sm font-medium">{@label}</span>
        <select
          id={@id}
          name={@name}
          class={[@class || "w-full select", @errors != [] && (@error_class || "select-error")]}
          multiple={@multiple}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          {Phoenix.HTML.Form.options_for_select(@options, @value)}
        </select>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label>
        <span :if={@label} class="label mb-1 text-sm font-medium">{@label}</span>
        <textarea
          id={@id}
          name={@name}
          class={[
            @class || "w-full textarea",
            @errors != [] && (@error_class || "textarea-error")
          ]}
          {@rest}
        >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # All other inputs: text, datetime-local, url, password, etc.
  def input(assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label>
        <span :if={@label} class="label mb-1 text-sm font-medium">{@label}</span>
        <div class={[@icon && "relative"]}>
          <div :if={@icon} class="absolute inset-y-0 left-0 flex items-center pl-3 pointer-events-none">
            <.icon name={@icon} class="size-4 text-base-content/40" />
          </div>
          <input
            type={@type}
            name={@name}
            id={@id}
            value={Phoenix.HTML.Form.normalize_value(@type, @value)}
            class={[
              @class || "w-full input",
              @icon && "pl-10",
              @errors != [] && (@error_class || "input-error")
            ]}
            {@rest}
          />
        </div>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  defp error(assigns) do
    ~H"""
    <p class="mt-1.5 flex gap-2 items-center text-sm text-error">
      <.icon name="hero-exclamation-circle" class="size-4 shrink-0" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  # ────────────────────────────────────────────────────────
  # Badge
  # ────────────────────────────────────────────────────────

  @doc """
  Renders a status badge.

  ## Examples

      <.badge variant="success">Active</.badge>
      <.badge variant="warning" size="sm">Expiring</.badge>
  """
  attr :variant, :string,
    default: "neutral",
    values: ~w(success warning error info neutral primary secondary)

  attr :size, :string, default: "md", values: ~w(sm md)
  attr :class, :any, default: nil

  slot :inner_block, required: true

  def badge(assigns) do
    variant_classes = %{
      "success" => "badge-success",
      "warning" => "badge-warning",
      "error" => "badge-error",
      "info" => "badge-info",
      "neutral" => "badge-neutral",
      "primary" => "badge-primary",
      "secondary" => "badge-secondary"
    }

    size_classes = %{
      "sm" => "badge-sm text-xs",
      "md" => "text-xs"
    }

    assigns =
      assign(assigns, :computed_class, [
        "badge rounded-full font-medium",
        Map.get(variant_classes, assigns.variant, "badge-neutral"),
        Map.get(size_classes, assigns.size, ""),
        assigns.class
      ])

    ~H"""
    <span class={@computed_class}>
      {render_slot(@inner_block)}
    </span>
    """
  end

  # ────────────────────────────────────────────────────────
  # Avatar
  # ────────────────────────────────────────────────────────

  @doc """
  Renders a user avatar with image or generated initials.

  ## Examples

      <.avatar name="John Doe" size="md" />
      <.avatar name="Jane" src="/uploads/avatar.jpg" size="lg" />
  """
  attr :name, :string, default: "U", doc: "user name for initials generation"
  attr :src, :string, default: nil, doc: "image URL"
  attr :size, :string, default: "md", values: ~w(sm md lg)
  attr :class, :any, default: nil

  def avatar(assigns) do
    size_classes = %{
      "sm" => "w-8 h-8 text-xs",
      "md" => "w-10 h-10 text-sm",
      "lg" => "w-14 h-14 text-lg"
    }

    initials =
      assigns.name
      |> String.split(~r/\s+/, trim: true)
      |> Enum.take(2)
      |> Enum.map(&String.first/1)
      |> Enum.join()
      |> String.upcase()

    assigns =
      assigns
      |> assign(:initials, initials)
      |> assign(:size_class, Map.get(size_classes, assigns.size, "w-10 h-10 text-sm"))

    ~H"""
    <div class={["rounded-full shrink-0 overflow-hidden", @size_class, @class]}>
      <img :if={@src} src={@src} alt={@name} class="w-full h-full object-cover" />
      <div
        :if={!@src}
        class="w-full h-full bg-primary/15 flex items-center justify-center"
      >
        <span class="font-bold text-primary">{@initials}</span>
      </div>
    </div>
    """
  end

  # ────────────────────────────────────────────────────────
  # Dropdown
  # ────────────────────────────────────────────────────────

  @doc """
  Renders an action dropdown menu.

  ## Examples

      <.dropdown id="user-actions">
        <:trigger>
          <.button variant="ghost" size="sm" icon="hero-ellipsis-vertical">
            <span class="sr-only">Actions</span>
          </.button>
        </:trigger>
        <:item>
          <button phx-click="edit">Edit</button>
        </:item>
        <:item>
          <button phx-click="delete" class="text-error">Delete</button>
        </:item>
      </.dropdown>
  """
  attr :id, :string, required: true
  attr :class, :any, default: nil

  slot :trigger, required: true
  slot :item

  def dropdown(assigns) do
    ~H"""
    <div class={["dropdown dropdown-end", @class]} id={@id}>
      <div tabindex="0" role="button">
        {render_slot(@trigger)}
      </div>
      <ul
        tabindex="0"
        class="dropdown-content menu bg-base-100 rounded-xl z-50 w-48 p-1.5 shadow-lg border border-base-300/50"
      >
        <li :for={item <- @item}>
          {render_slot(item)}
        </li>
      </ul>
    </div>
    """
  end

  # ────────────────────────────────────────────────────────
  # Tooltip
  # ────────────────────────────────────────────────────────

  @doc """
  Renders a tooltip on hover.

  ## Examples

      <.tooltip text="Edit this item">
        <.button variant="ghost" size="sm" icon="hero-pencil"></.button>
      </.tooltip>
  """
  attr :text, :string, required: true
  attr :position, :string, default: "top", values: ~w(top bottom left right)
  attr :class, :any, default: nil

  slot :inner_block, required: true

  def tooltip(assigns) do
    position_class = %{
      "top" => "tooltip-top",
      "bottom" => "tooltip-bottom",
      "left" => "tooltip-left",
      "right" => "tooltip-right"
    }

    assigns = assign(assigns, :pos_class, Map.get(position_class, assigns.position, "tooltip-top"))

    ~H"""
    <div class={["tooltip", @pos_class, @class]} data-tip={@text}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  # ────────────────────────────────────────────────────────
  # Modal
  # ────────────────────────────────────────────────────────

  @doc """
  Renders a modal dialog.

  ## Examples

      <.modal id="confirm-delete" title="Delete Member">
        <p>Are you sure?</p>
      </.modal>

  JS.show(to: "#confirm-delete") to open, JS.hide(to: "#confirm-delete") to close.
  """
  attr :id, :string, required: true
  attr :title, :string, default: nil
  attr :size, :string, default: "md", values: ~w(sm md lg)

  slot :inner_block, required: true
  slot :actions

  def modal(assigns) do
    size_class = %{
      "sm" => "max-w-sm",
      "md" => "max-w-lg",
      "lg" => "max-w-3xl"
    }

    assigns = assign(assigns, :size_class, Map.get(size_class, assigns.size, "max-w-lg"))

    ~H"""
    <div
      id={@id}
      phx-mounted={@id && JS.show(to: "##{@id}")}
      class="hidden fixed inset-0 z-50"
    >
      <div
        class="fixed inset-0 bg-black/50 backdrop-blur-sm"
        phx-click={hide_modal(@id)}
      />
      <div class="fixed inset-0 overflow-y-auto">
        <div class="flex min-h-full items-center justify-center p-4">
          <div class={[
            "relative w-full bg-base-100 rounded-2xl shadow-2xl p-6",
            @size_class
          ]}>
            <div :if={@title} class="flex items-center justify-between mb-4">
              <h3 class="text-lg font-semibold">{@title}</h3>
              <button
                type="button"
                class="btn btn-ghost btn-sm btn-circle"
                phx-click={hide_modal(@id)}
                aria-label="Close"
              >
                <.icon name="hero-x-mark" class="size-5" />
              </button>
            </div>
            {render_slot(@inner_block)}
            <div :if={@actions != []} class="mt-6 flex justify-end gap-3">
              {render_slot(@actions)}
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp hide_modal(id) do
    JS.hide(to: "##{id}",
      transition: {"ease-in duration-200", "opacity-100", "opacity-0"}
    )
  end

  # ────────────────────────────────────────────────────────
  # Header (kept for backwards compatibility)
  # ────────────────────────────────────────────────────────

  @doc """
  Renders a header with title. Prefer `page_header` from LayoutComponents for new pages.
  """
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

  # ────────────────────────────────────────────────────────
  # Table (kept for backwards compatibility)
  # ────────────────────────────────────────────────────────

  @doc """
  Renders a basic table. Prefer `data_table` from DataComponents for new pages.
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil
  attr :row_click, :any, default: nil

  attr :row_item, :any,
    default: &Function.identity/1

  slot :col, required: true do
    attr :label, :string
  end

  slot :action

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <table class="table table-zebra">
      <thead>
        <tr>
          <th :for={col <- @col}>{col[:label]}</th>
          <th :if={@action != []}>
            <span class="sr-only">{gettext("Actions")}</span>
          </th>
        </tr>
      </thead>
      <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}>
        <tr :for={row <- @rows} id={@row_id && @row_id.(row)}>
          <td
            :for={col <- @col}
            phx-click={@row_click && @row_click.(row)}
            class={@row_click && "hover:cursor-pointer"}
          >
            {render_slot(col, @row_item.(row))}
          </td>
          <td :if={@action != []} class="w-0 font-semibold">
            <div class="flex gap-4">
              <%= for action <- @action do %>
                {render_slot(action, @row_item.(row))}
              <% end %>
            </div>
          </td>
        </tr>
      </tbody>
    </table>
    """
  end

  # ────────────────────────────────────────────────────────
  # List
  # ────────────────────────────────────────────────────────

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title">{@post.title}</:item>
      </.list>
  """
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

  # ────────────────────────────────────────────────────────
  # Icon
  # ────────────────────────────────────────────────────────

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  ## Examples

      <.icon name="hero-x-mark" />
      <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :any, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  # ────────────────────────────────────────────────────────
  # Brand Logo
  # ────────────────────────────────────────────────────────

  @doc """
  Renders the FitTrackerz brand logo as an inline SVG.
  """
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

  # ────────────────────────────────────────────────────────
  # JS Commands
  # ────────────────────────────────────────────────────────

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

  # ────────────────────────────────────────────────────────
  # Translation Helpers
  # ────────────────────────────────────────────────────────

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    if count = opts[:count] do
      Gettext.dngettext(FitTrackerzWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(FitTrackerzWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
