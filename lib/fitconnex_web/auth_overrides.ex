defmodule FitconnexWeb.AuthOverrides do
  use AshAuthentication.Phoenix.Overrides
  alias AshAuthentication.Phoenix.Components

  override Components.Banner do
    set(:image_url, nil)
    set(:text_class, "text-3xl font-brand text-center")
    set(:text, "FITTRACKRPRO")
  end

  override Components.Password do
    set(:register_extra_component, &FitconnexWeb.AuthComponents.register_extra/1)
  end

  override Components.Password.Input do
    set(:field_class, "mb-4")
  end

  override Components.Password.RegisterForm do
    set(:root_class, "w-full max-w-md mx-auto" <> " " <> "password-form-container")
  end

  override Components.Password.SignInForm do
    set(:root_class, "w-full max-w-md mx-auto" <> " " <> "password-form-container")
  end
end

defmodule FitconnexWeb.AuthComponents do
  use Phoenix.Component
  import PhoenixHTMLHelpers.Form

  attr :form, :any, required: true

  def register_extra(assigns) do
    ~H"""
    <div>
      <label for="user_name" class="block text-sm font-medium mb-1">Name</label>
      {text_input(
        @form,
        :name,
        placeholder: "Your full name",
        class: "input input-bordered w-full",
        id: "user_name"
      )}
    </div>
    """
  end
end
